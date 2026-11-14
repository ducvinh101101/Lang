// CHỈ DÙNG KHI PHÁT TRIỂN (bản debug trên máy tính): đọc lệnh thử từ tệp
//   %TEMP%\danbau_trai_dat\thu_lenh.txt   (mỗi dòng một câu, như câu người dùng vừa nói)
// để kiểm thử toàn bộ luồng nói → hiểu → trả lời mà không cần nói vào micro. Bản phát hành và bản web không có.
export 'dev_commands_stub.dart' if (dart.library.io) 'dev_commands_io.dart';
