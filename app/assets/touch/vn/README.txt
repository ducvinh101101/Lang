Thư mục dữ liệu địa lý THẬT cho F3 (chạm địa hình): độ cao, độ dốc NASA SRTMGL30; mặt nước, mật độ dân số NASA SEDAC GPWv4.
Tạo bằng: cd data_nasa && python crawl_f3.py (cần tài khoản NASA Earthdata) && python build_f3.py
rồi: python pipeline/import_data_nasa.py  (chép data_nasa/touch/vn → đây).
Chưa có grid.json ở đây thì app tự dùng cách ước lượng cũ.
