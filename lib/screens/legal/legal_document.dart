enum LegalDocument {
  terms,
  privacy,
  support,
  accountDeletion,
}

extension LegalDocumentInfo on LegalDocument {
  String get title {
    switch (this) {
      case LegalDocument.terms:
        return '利用規約';
      case LegalDocument.privacy:
        return 'プライバシーポリシー';
      case LegalDocument.support:
        return 'サポート';
      case LegalDocument.accountDeletion:
        return 'アカウント削除';
    }
  }

  String get assetPath {
    switch (this) {
      case LegalDocument.terms:
        return 'legal/terms.html';
      case LegalDocument.privacy:
        return 'legal/privacy.html';
      case LegalDocument.support:
        return 'legal/support.html';
      case LegalDocument.accountDeletion:
        return 'legal/account-deletion.html';
    }
  }

  static LegalDocument? fromHref(String href) {
    final file = href.split('/').last.split('#').first;
    switch (file) {
      case 'terms.html':
        return LegalDocument.terms;
      case 'privacy.html':
        return LegalDocument.privacy;
      case 'support.html':
        return LegalDocument.support;
      case 'account-deletion.html':
        return LegalDocument.accountDeletion;
      default:
        return null;
    }
  }
}
