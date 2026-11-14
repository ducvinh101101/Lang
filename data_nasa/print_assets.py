# print_assets.py — in danh sách thư mục để dán vào pubspec.yaml (sau khi chép touch/ vào assets/touch/ của app)
import glob
print("    - assets/touch/")
for d in sorted(glob.glob("touch/*/")):
    print(f"    - assets/{d.replace(chr(92), '/')}")
