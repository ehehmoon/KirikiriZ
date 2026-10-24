# KirikiriZ for Android

안드로이드에서 **키리키리Z(Kirikiri Z) 1.2.0.3** 엔진 기반 게임을 실행하기 위한 플레이어입니다.

엔진 본체는 직접 새로 작성하지 않고, Kirikiroid2를 현대적인 빌드 체계(CMake + vcpkg + NDK r28)로 재구성한
오픈소스 에뮬레이터 [krkr2](https://github.com/2468785842/krkr2)(MIT)를 `upstream/krkr2` 서브모듈로 포함합니다.
이 저장소는 그 위에 KrkrZ 1.2.0.3 호환 패치, 빌드 스크립트, APK 자동 빌드(GitHub Actions)를 더합니다.

## 구성

| 경로 | 내용 |
|---|---|
| `upstream/krkr2/` | 엔진 본체 (서브모듈, 커밋 고정) |
| `patches/0001-krkrz-1.2.0.3-compat.patch` | KrkrZ 1.2.0.3 호환 모드 (아래 참고) |
| `patches/0002-selectable-abis.patch` | `-PkrkrAbis=` 로 빌드할 ABI 선택 |
| `scripts/setup-android-env.sh` | Android SDK/NDK 28, CMake 3.31.1, vcpkg 설치 |
| `scripts/build-android.sh` | 패치 적용 → APK 빌드 → `dist/` 에 복사 |
| `.github/workflows/build-android.yml` | 푸시할 때마다 APK를 빌드해 아티팩트로 업로드 |

## KrkrZ 1.2.0.3 호환 모드

krkr2는 원래 자신을 **KiriKiri2 2.32.2.426**으로 보고하고, TJS 전처리 상수 `kirikiriz`를 정의하지 않습니다.
원본 KrkrZ는 이 상수를 정의하므로, `@if (kirikiriz)`로 분기하거나 `System.versionString`/`System.versionInformation`으로
엔진을 확인하는 KrkrZ 게임은 krkr2에서 잘못된 경로로 실행될 수 있습니다. 패치 `0001`은 다음을 바꿉니다.

- TJS 전처리 상수 `kirikiriz = 1` 정의
- `System.versionString` → `1.2.0.3`
- `System.versionInformation` / about 문자열 → `Kirikiri Z Runtime Core version 1.2.0.3 ...`

호환 모드는 기본으로 켜져 있습니다. KiriKiri2용 게임이 오작동하거나 게임이 다른 버전 번호를 요구하면,
게임 폴더의 `Kirikiroid2Preference.xml`(앱의 게임별 설정을 한 번 저장하면 생성됨)에 항목을 추가합니다.

```xml
<Item key="krkrzcompat" value="no"/>        <!-- 호환 모드 끄기 (KiriKiri2 2.32로 동작) -->
<Item key="krkrzversion" value="1.2.0.3"/>  <!-- 보고할 버전 번호 바꾸기 -->
```

## APK 받기

### GitHub Actions (권장)

이 저장소에 푸시하면 `Build Android APK` 워크플로가 실행되고, 완료되면 **Releases**의 `nightly`(사전 릴리스)에
최신 APK가 올라갑니다. 실행 페이지의 **Artifacts**에도 7일간 올라가지만, 계정의 아티팩트 저장 용량이 차면 생략됩니다.
`v1.0.0`처럼 `v`로 시작하는 태그를 푸시하면 그 이름의 Release에 APK가 첨부됩니다.

- 첫 빌드는 vcpkg 의존성(ffmpeg, OpenCV, Boost, cocos2d-x 등)을 전부 컴파일하므로 1시간 남짓 걸립니다. 이후에는 캐시를 씁니다.
- 다른 ABI가 필요하면 Actions 탭 → `Build Android APK` → **Run workflow**에서 `arm64-v8a,x86_64`처럼 지정합니다.
- **서명 키**: 저장소 Secrets에 `ANDROID_KEYSTORE_BASE64`(keystore 파일을 base64로 인코딩한 값), `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`를 등록하세요. 등록하지 않으면 빌드마다 임시 키로 서명되므로, 새 버전을 설치할 때
  기존 앱을 먼저 삭제해야 합니다.

### 직접 빌드 (Linux)

필요: JDK 17 이상, git, curl, unzip, bison 3.8+, python3, nasm, yasm, 디스크 약 30GB.

```bash
git clone --recursive <이 저장소 URL>
cd KirikiriZ
./scripts/setup-android-env.sh        # ./.toolchain 에 SDK/NDK/vcpkg 설치
./scripts/build-android.sh release    # 결과물: dist/*.apk
# ABIS=arm64-v8a,x86_64 ./scripts/build-android.sh release   # 여러 ABI
```

직접 빌드할 때 만든 서명 키는 `.toolchain/release.keystore`에 보관되어 다음 빌드에도 재사용됩니다.

## 게임 실행 방법

1. APK를 설치하고 실행한 뒤 **모든 파일 접근 권한**을 허용합니다 (Android 11 이상).
2. PC의 게임 설치 폴더(`data.xp3`, `*.xp3`, `plugin/` 등이 있는 폴더)를 통째로 기기 저장소에 복사합니다.
   `krkrz.exe`/`*.exe`와 `*.dll`은 안드로이드에서 쓰이지 않지만 같이 두어도 문제없습니다.
3. 앱의 파일 선택 화면에서 그 폴더로 이동해 `data.xp3`(또는 `startup.tjs`)를 선택합니다.

## 호환성과 한계

- **Windows 플러그인 DLL**: 안드로이드에서는 DLL을 불러올 수 없습니다. 대신 아래 플러그인은 엔진에 내장 구현되어 있어,
  `Plugins.link("xxx.dll")`을 호출하면 이름(대소문자 무시)으로 내장 구현이 연결됩니다.
  `KAGParserEx` `ScriptsEx` `TextRender` `addFont` `csvParser` `dirlist` `emoteplayer` `motionplayer` `psbfile` `psd`
  `fftgraph` `fstat` `getSample` `getabout` `json` `varfile` `saveStruct` `layerExDraw` `layerExMovie` `perspective`
  `win32dialog` `windowEx` `wutcwf` `xp3filter` `krkrsteam` `steam_api` `DrawDeviceForSteam`
  내장 구현이 없는 DLL은 로그에 오류만 남기고 넘어가므로, 그 플러그인에 의존하는 기능은 동작하지 않습니다.
- **암호화된 XP3**: 상용 게임의 상당수는 XP3를 독자적으로 암호화합니다. Kirikiroid2와 같은 방식으로, 게임 폴더에
  해당 게임용 복호화 스크립트 `xp3filter.tjs`를 두면 읽을 수 있습니다. 이 저장소는 복호화 스크립트를 제공하지 않습니다.
- **동영상**: 오프닝 등 동영상은 ffmpeg로 재생하므로 대부분의 WMV/MPEG/OGV를 재생할 수 있지만, 일부 게임 전용 포맷은 재생되지 않을 수 있습니다.
- **실기기 검증**: 이 저장소의 변경(호환 패치, 빌드 구성)은 컴파일 검사와 Gradle 구성 검사까지만 마쳤고, 실제 게임을
  실기기에서 돌려 보지는 않았습니다. 문제가 생기면 앱 로그와 함께 이슈로 남겨 주세요.

## 업스트림 갱신

```bash
git -C upstream/krkr2 fetch origin && git -C upstream/krkr2 checkout <새 커밋>
./scripts/apply-patches.sh   # 패치가 충돌하면 patches/*.patch 를 갱신
git add upstream/krkr2 && git commit -m "Update krkr2"
```

## 라이선스

- 이 저장소의 스크립트와 패치: MIT
- 엔진(krkr2, Kirikiri Z, Kirikiroid2 기반 코드)과 서드파티 구성 요소: `upstream/krkr2/LICENSE` 및 각 구성 요소의 라이선스를 따릅니다.
