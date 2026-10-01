import 'dart:async';

/// Available actions triggered from the 3-dots menu on Today's Milk card (Node 14:2).
enum MilkCardActionType {
  /// View historical milk collection logs
  viewHistory,

  /// Export daily milk summary report
  exportSummary,
}

/// Typed result from executing a milk card action via the connector.
abstract class MilkActionConnectorResult {
  const MilkActionConnectorResult();
}

/// Returned when the connector operation completes successfully.
class MilkActionSuccess extends MilkActionConnectorResult {
  final String? message;
  final Map<String, dynamic>? data;
  const MilkActionSuccess({this.message, this.data});
}

/// Returned when the connector operation fails with an error message.
class MilkActionFailure extends MilkActionConnectorResult {
  final String errorMessage;
  const MilkActionFailure(this.errorMessage);
}

/// Returned when no backend is connected to the connector.
class MilkActionNotConnected extends MilkActionConnectorResult {
  const MilkActionNotConnected();
}

/// Domain connector interface for Today's Milk card actions.
///
/// **Inputs**: [action] type ([MilkCardActionType]), optional [params] payload map.
/// **Outputs**: [MilkActionConnectorResult] ([MilkActionSuccess], [MilkActionFailure], or [MilkActionNotConnected]).
/// **Errors**: Async execution failures are captured into [MilkActionFailure] or [MilkActionNotConnected].
/// NO database or HTTP dependencies allowed in this interface.
abstract class MilkCardActionsConnector {
  /// Executes a menu action triggered from the 3-dots icon on Today's Milk card.
  Future<MilkActionConnectorResult> executeAction(
    MilkCardActionType action, {
    Map<String, dynamic>? params,
  });
}

/// Default connector implementation that returns [MilkActionNotConnected].
class DefaultMilkCardActionsConnector implements MilkCardActionsConnector {
  const DefaultMilkCardActionsConnector();

  @override
  Future<MilkActionConnectorResult> executeAction(
    MilkCardActionType action, {
    Map<String, dynamic>? params,
  }) async {
    return const MilkActionNotConnected();
  }
}
