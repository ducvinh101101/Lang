// MÁY CHỦ CỦA APP (Vercel) — app trên điện thoại / máy tính CHẠY ĐƯỢC KHÔNG CẦN máy chủ này; nó chỉ để:
//  • tải bộ nghe tiếng Anh lần đầu chuyển sang tiếng Anh (/models/en_parakeet/)
//  • trợ lý AI khi app không có khoá Gemini riêng (/api/gemini — khoá nằm trên máy chủ, không nằm trong app)
// Đổi khi build: --dart-define=APP_SERVER=https://<tên-khác>.vercel.app
const appServer = String.fromEnvironment('APP_SERVER', defaultValue: 'https://sense-app-two.vercel.app');
