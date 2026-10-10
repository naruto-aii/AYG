import "npm:reflect-metadata@0.2.2";
import {
  BasicConstraintsExtension,
  X509Certificate,
} from "npm:@peculiar/x509@2.1.0";

/// Apple の署名用証明書に付く OID。葉と中間で違う。
const leafCertificateOid = "1.2.840.113635.100.6.11.1";
const intermediateCertificateOid = "1.2.840.113635.100.6.2.1";
/// Apple のライブラリと同じ、時刻の許容ずれ。
const maxSkewMs = 60_000;

/// Apple の VerificationStatus と同じ番号。ログの状態名に使う。
export enum VerificationStatus {
  OK = 0,
  VERIFICATION_FAILURE = 1,
  RETRYABLE_VERIFICATION_FAILURE = 2,
  INVALID_APP_IDENTIFIER = 3,
  INVALID_ENVIRONMENT = 4,
  INVALID_CHAIN_LENGTH = 5,
  INVALID_CERTIFICATE = 6,
  FAILURE = 7,
}

export class StoreVerificationError extends Error {
  status: number;

  constructor(status: number, cause?: unknown) {
    const inner = cause instanceof Error ? cause : undefined;
    super(inner?.message ?? "", inner ? { cause: inner } : undefined);
    this.name = "StoreVerificationError";
    this.status = status;
  }
}

export type SignedPayload = {
  bundleId?: string;
  environment?: string;
  productId?: string;
  originalTransactionId?: string;
  transactionId?: string | number;
  appAccountToken?: string;
  expiresDate?: number;
  revocationDate?: number;
  revocationReason?: number;
  offerType?: number;
  offerDiscountType?: string;
  isUpgraded?: boolean;
  signedDate?: number;
  gracePeriodExpiresDate?: number;
  autoRenewStatus?: number;
  notificationUUID?: string;
  notificationType?: string;
  subtype?: string | null;
  data?: NotificationIdentity & {
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
  summary?: NotificationIdentity;
  externalPurchaseToken?: NotificationIdentity & { externalPurchaseId?: string };
  appData?: NotificationIdentity;
  [key: string]: unknown;
};

type NotificationIdentity = {
  environment?: string;
  bundleId?: string;
  appAppleId?: number;
};

/// Edge Runtime で動く検証器。Node の crypto.X509Certificate は使わない。
/// OCSP は、その確認が Node の crypto に依存し Edge では動かないため行わない。
/// 返金で加入を止めるのは、取引の revocationDate と App Store の通知である。
export class EdgeSignedDataVerifier {
  constructor(
    private readonly roots: Uint8Array[],
    private readonly onlineChecks: boolean,
    private readonly environment: string,
    private readonly bundleId: string,
    private readonly appAppleId: number,
  ) {}

  verifyAndDecodeTransaction(jws: string): Promise<SignedPayload> {
    return this.verifyJwt(jws).then((payload) => {
      if (payload.bundleId !== this.bundleId) {
        throw new StoreVerificationError(VerificationStatus.INVALID_APP_IDENTIFIER);
      }
      if (payload.environment !== this.environment) {
        throw new StoreVerificationError(VerificationStatus.INVALID_ENVIRONMENT);
      }
      return payload;
    });
  }

  verifyAndDecodeRenewalInfo(jws: string): Promise<SignedPayload> {
    return this.verifyJwt(jws).then((payload) => {
      if (payload.environment !== this.environment) {
        throw new StoreVerificationError(VerificationStatus.INVALID_ENVIRONMENT);
      }
      return payload;
    });
  }

  verifyAndDecodeNotification(jws: string): Promise<SignedPayload> {
    return this.verifyJwt(jws).then((payload) => {
      const identity = notificationIdentity(payload);
      if (
        this.bundleId !== identity.bundleId ||
        (this.environment === "Production" && this.appAppleId !== identity.appAppleId)
      ) {
        throw new StoreVerificationError(VerificationStatus.INVALID_APP_IDENTIFIER);
      }
      if (this.environment !== identity.environment) {
        throw new StoreVerificationError(VerificationStatus.INVALID_ENVIRONMENT);
      }
      return payload;
    });
  }

  private async verifyJwt(jws: string): Promise<SignedPayload> {
    try {
      const parts = jws.split(".");
      if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
        throw new StoreVerificationError(VerificationStatus.INVALID_CERTIFICATE);
      }
      let header: { alg?: unknown; x5c?: unknown };
      let payload: SignedPayload;
      try {
        header = JSON.parse(bytesToText(base64UrlToBytes(parts[0])));
        const parsed = JSON.parse(bytesToText(base64UrlToBytes(parts[1])));
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
          throw new StoreVerificationError(VerificationStatus.FAILURE);
        }
        payload = parsed as SignedPayload;
      } catch (error) {
        if (error instanceof StoreVerificationError) {
          throw error;
        }
        throw new StoreVerificationError(VerificationStatus.INVALID_CERTIFICATE, error);
      }
      const chain = header.x5c;
      if (!Array.isArray(chain) || chain.length !== 3 || chain.some((item) => typeof item !== "string")) {
        throw new StoreVerificationError(VerificationStatus.INVALID_CHAIN_LENGTH);
      }
      if (header.alg !== "ES256") {
        throw new StoreVerificationError(
          VerificationStatus.VERIFICATION_FAILURE,
          new Error("unsupported alg"),
        );
      }
      let leaf: X509Certificate;
      let intermediate: X509Certificate;
      try {
        leaf = new X509Certificate(standardBase64ToBytes(chain[0] as string));
        intermediate = new X509Certificate(standardBase64ToBytes(chain[1] as string));
      } catch (error) {
        throw new StoreVerificationError(VerificationStatus.INVALID_CERTIFICATE, error);
      }
      const effectiveDate = this.onlineChecks ? new Date() : signedDateOf(payload);
      const publicKey = await this.verifyChain(leaf, intermediate, effectiveDate);
      const signingInput = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
      let signatureOk = false;
      try {
        signatureOk = await crypto.subtle.verify(
          { name: "ECDSA", hash: "SHA-256" },
          publicKey,
          base64UrlToBytes(parts[2]),
          signingInput,
        );
      } catch (error) {
        throw new StoreVerificationError(VerificationStatus.VERIFICATION_FAILURE, error);
      }
      if (!signatureOk) {
        throw new StoreVerificationError(
          VerificationStatus.VERIFICATION_FAILURE,
          new Error("signature mismatch"),
        );
      }
      return payload;
    } catch (error) {
      if (error instanceof StoreVerificationError) {
        throw error;
      }
      throw new StoreVerificationError(
        VerificationStatus.VERIFICATION_FAILURE,
        error instanceof Error ? error : undefined,
      );
    }
  }

  private async verifyChain(
    leaf: X509Certificate,
    intermediate: X509Certificate,
    effectiveDate: Date,
  ): Promise<CryptoKey> {
    let root: X509Certificate | undefined;
    let unsupported: Error | undefined;
    for (const der of this.roots) {
      const candidate = new X509Certificate(copyBytes(der));
      let signedByRoot = false;
      try {
        signedByRoot = await intermediate.verify({
          publicKey: candidate.publicKey,
          signatureOnly: true,
        });
      } catch (error) {
        // P-384 の鍵に SHA-256 を渡すと、Edge の WebCrypto は Not implemented を投げる。
        // そのルートは合わないものとして、次の同梱ルートを試す。
        if (!(error instanceof Error) || error.name !== "NotSupportedError") {
          throw error;
        }
        unsupported = error;
      }
      if (signedByRoot && intermediate.issuer === candidate.subject) {
        root = candidate;
      }
    }
    const signedByIntermediate = await leaf.verify({
      publicKey: intermediate.publicKey,
      signatureOnly: true,
    });
    const namesMatch = leaf.issuer === intermediate.subject;
    const intermediateIsCa = intermediate.getExtension(BasicConstraintsExtension)?.ca === true;
    const leafOid = hasExtension(leaf, leafCertificateOid);
    const intermediateOid = hasExtension(intermediate, intermediateCertificateOid);
    if (!root) {
      throw new StoreVerificationError(VerificationStatus.VERIFICATION_FAILURE, unsupported);
    }
    if (!signedByIntermediate || !namesMatch || !intermediateIsCa || !leafOid || !intermediateOid) {
      throw new StoreVerificationError(VerificationStatus.VERIFICATION_FAILURE);
    }
    checkDates(leaf, effectiveDate);
    checkDates(intermediate, effectiveDate);
    checkDates(root, effectiveDate);
    return await leaf.publicKey.export({ name: "ECDSA", namedCurve: "P-256" }, ["verify"]);
  }
}

function hasExtension(cert: X509Certificate, oid: string): boolean {
  return cert.getExtension(oid) != null;
}

function checkDates(cert: X509Certificate, effectiveDate: Date) {
  if (
    cert.notBefore.getTime() > effectiveDate.getTime() + maxSkewMs ||
    cert.notAfter.getTime() < effectiveDate.getTime() - maxSkewMs
  ) {
    throw new StoreVerificationError(VerificationStatus.INVALID_CERTIFICATE);
  }
}

function signedDateOf(payload: SignedPayload): Date {
  if (payload.signedDate == null) {
    return new Date();
  }
  const date = new Date(payload.signedDate);
  return Number.isNaN(date.getTime()) ? new Date() : date;
}

function notificationIdentity(payload: SignedPayload): NotificationIdentity {
  if (payload.data) {
    return payload.data;
  }
  if (payload.summary) {
    return payload.summary;
  }
  if (payload.externalPurchaseToken) {
    const token = payload.externalPurchaseToken;
    const purchaseId = token.externalPurchaseId ?? "";
    return {
      bundleId: token.bundleId,
      appAppleId: token.appAppleId,
      environment: purchaseId.startsWith("SANDBOX") ? "Sandbox" : "Production",
    };
  }
  if (payload.appData) {
    return payload.appData;
  }
  return {};
}

function copyBytes(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const copy = new Uint8Array(new ArrayBuffer(bytes.byteLength));
  copy.set(bytes);
  return copy;
}

function standardBase64ToBytes(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replace(/\s+/g, "");
  const binary = atob(normalized);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function base64UrlToBytes(value: string): Uint8Array<ArrayBuffer> {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  return standardBase64ToBytes(padded + pad);
}

function bytesToText(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}
