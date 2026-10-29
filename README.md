# 약물 검색 사전 - 브라우저에서 APK 빌드

GitHub에서 새 Public 또는 Private 저장소를 생성하고 이 폴더 안의 `lib`와 `.github` 폴더 및 `README.md`를 업로드하세요.
(압축 파일 자체를 업로드하면 자동으로 풀리지 않습니다.)

Actions 탭 > Build Android APK > Run workflow 를 선택하거나 main 브랜치에 업로드하면 자동으로 빌드합니다.
빌드 성공 후 실행 상세 페이지의 Artifacts에서 `medicine-dictionary-apk`를 내려받으면 ZIP 안에 `app-release.apk`가 있습니다.

참고: 최초 빌드는 Flutter/Android 다운로드 때문에 시간이 걸릴 수 있고 환경에 따라 실패할 수 있습니다. APK는 앱 개발용 기본 서명으로 만들어지며 Play Store 게시용이 아닙니다.
