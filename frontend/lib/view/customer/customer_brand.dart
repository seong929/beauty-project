const customerBrandName = '하나';

// 표시용 제조사·브랜드 문구만 바꾸고 DB 상품 정보와 식별자는 유지한다.
String customerBrandText(String text) =>
    text.replaceAll('소담', customerBrandName);
