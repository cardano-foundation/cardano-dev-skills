from enum import Enum


class ProcessStatus(str, Enum):
    """Status of process"""

    NOT_STARTED = "not_started"
    CHECKING_REFERENCE_SCRIPTS = "checking_script"
    CREATING_SCRIPT = "creating_script"
    BUILDING_TRANSACTION = "building_transaction"
    TRANSACTION_BUILT = "built"
    SIGNING_TRANSACTION = "signing_transaction"
    TRANSACTION_SIGNED = "signed"
    SUBMITTING_TRANSACTION = "submitting_transaction"
    TRANSACTION_SUBMITTED = "submitted"
    TRANSACTION_CONFIRMED = "confirmed"
    WAITING_CONFIRMATION = "waiting_confirmation"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED_BY_USER = "cancelled_by_user"
    VERIFICATION_FAILURE = "verification_failure"
