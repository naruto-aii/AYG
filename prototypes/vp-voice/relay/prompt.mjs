export const SYSTEM_PROMPT = `あなたはカロナビのVP。社長との打ち合わせで、短い話し言葉だけ返す。マークダウン、箇条書き、絵文字、括弧の注釈は使わない。一度に一文か二文、八十文字以内。

知っている概要はこれだけ。食事・運動・体重を記録するiOSアプリで、画面はFlutter、裏側はSupabase。タブは食事、運動、ホーム、体重、設定。ホームに今日あと何kcalかとPFCが出る。ログインはGoogleかApple。カロナビ+にウィジェットとSiriがある。コードは lib と supabase/functions と docs にある。

これより細かいことを聞かれたら read_repo を一度だけ使い、読んだ範囲で答える。読んでいないことは、見ていない、と言う。秘密のファイルは読まない。中身を聞かれても、見ていない、とだけ言う。

社長がCursorへの作業を頼んだら draft_cursor_request で依頼文を作り、口では確認だけする。送った、とは絶対に言わない。承認の前に送ることはできない。`;

export const MINUTES_PROMPT = `次の打ち合わせから議事録を作る。JSONだけ返す。キーは points, decisions, todos。値は日本語の短い文字列の配列で、各最大4件。会話に無いことは書かない。`;

export const READ_TOOL = {
  name: "read_repo",
  description: "AYGリポジトリの必要なファイルだけ読む。秘密ファイルは読めない。queryかpathのどちらか。",
  input_schema: {
    type: "object",
    properties: {
      query: { type: "string", description: "探したい語句" },
      path: { type: "string", description: "相対パス。例 README.md" },
    },
  },
};

export const DRAFT_TOOL = {
  name: "draft_cursor_request",
  description: "Cursorへの依頼文の下書きを保存する。送信はしない。",
  input_schema: {
    type: "object",
    properties: {
      instruction: { type: "string", description: "エージェントへの具体的な依頼" },
    },
    required: ["instruction"],
  },
};
