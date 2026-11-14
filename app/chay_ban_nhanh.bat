@echo off
rem Chay Lang ban PHAT HANH (nhanh va muot hon nhieu so voi Run trong VS Code, von la ban debug)
if exist .env (
    flutter run -d windows --release --dart-define-from-file=.env
) else if exist keys.json (
    flutter run -d windows --release --dart-define-from-file=keys.json
) else (
    flutter run -d windows --release
)
