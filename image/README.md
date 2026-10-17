# Image Reference Index

이 폴더는 카탈로그 UI 참고 이미지와 문서를 보관한다. UI를 수정하기 전에는 이 목록과 GitHub의 image/ 폴더 최신 파일 목록을 모두 확인한다.

## 현재 파일

| 파일명 | 유형 | 용도 | Raw URL |
|---|---|---|---|
| `카탈로그 UI 20261017 14.jpg` | JPG | 2026-10-17 카탈로그 UI 참고 이미지 | https://raw.githubusercontent.com/kimmina000-alt/Roblox-FashionSocial/catalog-ui-redesign/image/%EC%B9%B4%ED%83%88%EB%A1%9C%EA%B7%B8%20UI%2020261017%2014.jpg |
| `카탈로그 UI 20261016 18.png` | PNG | 2026-10-16 카탈로그 UI 참고 이미지 | https://raw.githubusercontent.com/kimmina000-alt/Roblox-FashionSocial/catalog-ui-redesign/image/%EC%B9%B4%ED%83%88%EB%A1%9C%EA%B7%B8%20UI%2020261016%2018.png |
| `카탈로그 UI [날짜에 방향 제어 문자 포함] 22.pdf` | PDF | 2026-10-16 카탈로그 UI 참고 문서. 실제 파일명에는 보이지 않는 Unicode 방향 제어 문자가 포함되어 있으므로, URL은 아래 Raw 주소를 그대로 사용한다. | https://raw.githubusercontent.com/kimmina000-alt/Roblox-FashionSocial/catalog-ui-redesign/image/%EC%B9%B4%ED%83%88%EB%A1%9C%EA%B7%B8%20UI%20%E2%80%8E2026%E2%80%8E%E2%80%8E1016%20%E2%80%8F%E2%80%8E22.pdf |
| `이미지 저장하는 곳` | 확장자 없음 | 파일명 작성 규칙 메모 | https://raw.githubusercontent.com/kimmina000-alt/Roblox-FashionSocial/catalog-ui-redesign/image/%EC%9D%B4%EB%AF%B8%EC%A7%80%20%EC%A0%80%EC%9E%A5%ED%95%98%EB%8A%94%20%EA%B3%B3 |

## Blob URL을 Raw URL로 변환

`https://github.com/{owner}/{repo}/blob/{branch}/{path}` → `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}`

`github.com`을 `raw.githubusercontent.com`으로 바꾸고 `/blob/`만 제거한다. 브랜치와 경로는 유지하며, 한글·공백·특수 문자와 파일명에 포함된 보이지 않는 Unicode 문자의 URL 인코딩을 보존한다. 가능하면 GitHub 파일 목록의 정확한 경로와 `download_url`을 사용한다.

## 새 파일 추가·변경 절차

1. 브랜치의 `image/` 폴더를 직접 조회해 현재 파일 목록을 확인한다. 인덱스만 믿지 않는다.
2. 파일명, 확장자, 경로를 정확히 확인하고 이 표를 갱신한다.
3. Raw URL을 실제로 열어 접근 가능 여부를 검증한다. URL을 구성한 것만으로 검증했다고 보지 않는다.
4. PNG/JPG는 이미지로 열어 확인하고, PDF는 PDF 뷰어나 페이지별 읽기 기능으로 확인한다.
5. 파일을 읽지 못하면 그 한계를 밝히고 내용을 확인했다고 주장하지 않는다.
6. 파일 추가·이름 변경·삭제 시 인덱스도 같은 변경에서 갱신한다.

브랜치 기반 Raw URL은 브랜치의 최신 파일을 가리킨다. 특정 버전을 고정해야 한다면 브랜치 대신 커밋 SHA를 사용한다.
