/// قواعد عرض التقييم زي التطبيقات الكبيرة: تقييم أو اتنين ما يكفوش يحكموا على حد،
/// فالرقم بيظهر من أول 3 تقييمات، وقبلها «جديد» ومعاه عدد التقييمات.
/// الترتيب (الأعلى تقييمًا) بيوزن التقييم بعددها على السيرفر والموبايل: 5 من تقييم واحد مش زي 4.9 من 200.
const int ratingShownFrom = 3;

bool isRatingShown(int reviewsCount) => reviewsCount >= ratingShownFrom;

/// الرقم بعلامة عشرية واحدة، أو «جديد»
String ratingLabel(double rating, int reviewsCount) =>
    isRatingShown(reviewsCount) ? rating.toStringAsFixed(1) : 'جديد';

/// الرقم اللي يترسم، وصفر معناه «جديد»
double shownRating(double rating, int reviewsCount) => isRatingShown(reviewsCount) ? rating : 0;

String ratingCaption(int reviewsCount) => switch (reviewsCount) {
      0 => 'بدون تقييمات',
      1 => 'تقييم واحد',
      2 => 'تقييمين',
      _ => '$reviewsCount تقييم',
    };
