// 기능: 고객용 하나 브랜드 표시 문구.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

const customerBrandName = '하나';

// 표시용 제조사·브랜드 문구만 바꾸고 DB 상품 정보와 식별자는 유지한다.
String customerBrandText(String text) =>
    text.replaceAll('소담', customerBrandName);
