/// App-wide string constants for DairyFarm Pro.
///
/// CURRENCY: This app is built for Pakistan — all monetary values use PKR.
/// Always reference [AppStrings.currency] instead of hardcoding the symbol.
///
/// Centralising strings here makes localisation straightforward in the future
/// and prevents magic strings from being scattered across the codebase.
abstract final class AppStrings {
  // ── Currency ─────────────────────────────────────────────────────────────
  /// Pakistani Rupee symbol. Use this everywhere money is displayed.
  /// Example: '${AppStrings.currency} 15,200'
  static const String currency = 'Rs';

  /// Full currency name, used in reports or settings screens.
  static const String currencyFull = 'Pakistani Rupee (PKR)';

  // ── General ─────────────────────────────────────────────────────────────
  static const String appName = 'Farm Flow';
  static const String appTagline = 'Precision management for the modern herd.';

  // ── Auth screen ──────────────────────────────────────────────────────────
  static const String welcomeTitle = 'Welcome to Farm Flow';
  static const String loginButton = 'Login';
  static const String createFarmButton = 'Create Farm Profile';
  static const String usernameHint = 'Username';
  static const String passwordHint = 'Password';

  // ── Dashboard ────────────────────────────────────────────────────────────
  static const String greeting = 'Good Morning,';
  static const String todaysMilk = "Today's Milk";
  static const String activeCows = 'Active Cows';
  static const String totalHerd = 'Total Herd';
  static const String recentActivity = 'Recent Activity';
  static const String viewAll = 'View All';
  static const String weightUnit = 'Kg';
  static const String morningAbbr = 'M';
  static const String eveningAbbr = 'E';
  static const String pregnantBadge = 'Pregnant';

  // ── Bottom navigation ────────────────────────────────────────────────────
  static const String navHome = 'Home';
  static const String navMilk = 'Milk';
  static const String navBuyers = 'Buyers';
  static const String navHerd = 'Herd';

  // ── Milk entry ───────────────────────────────────────────────────────────
  static const String weightLabel = 'KG';
  static const String morning = 'Morning';
  static const String evening = 'Evening';
  static const String saveEntry = 'Save Entry';

  // ── Dodi / Buyer ledger ──────────────────────────────────────────────────
  static const String milkBuyers = 'Milk Buyers';
  static const String due = 'Due';
  static const String lastPayment = 'Last Payment:';
  static const String paid = 'Paid';
  static const String pending = 'Pending';
  static const String viewDetails = 'View Details ›';

  // ── Herd screen ──────────────────────────────────────────────────────────
  static const String herd = 'Herd';
  static const String filterAll = 'All';
  static const String filterMilking = 'Milking';
  static const String filterPregnant = 'Pregnant';
  static const String filterDry = 'Dry';
  static const String filterHeifer = 'Heifer';
  static const String filterBredHeifer = 'Bred Heifer';
  static const String monthOf9 = 'of 9';
  static const String startSpecialCare = 'Start Special Care';
  static const String healthStatus = 'Health Status';
  static const String optimal = 'Optimal';
  static const String midTerm = 'Mid-term';
}
