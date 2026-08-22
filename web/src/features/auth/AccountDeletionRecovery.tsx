import { useEffect, useRef } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthProvider";
import { AccountDeletionConfirmationModal } from "./AccountDeletionConfirmationModal";

/// Shows the deletion summary after another device removes the active account.
/// It stays above the current route until the player acknowledges it.
export function AccountDeletionRecovery() {
  const navigate = useNavigate();
  const location = useLocation();
  const initialLocationKey = useRef(location.key);
  const { accountDeletionNotice, acknowledgeAccountDeletion, validateAccountSession } = useAuth();

  useEffect(() => {
    if (location.key === initialLocationKey.current) return;
    initialLocationKey.current = location.key;
    void validateAccountSession();
  }, [location.key, validateAccountSession]);

  if (!accountDeletionNotice) return null;

  return <AccountDeletionConfirmationModal
    error={null}
    isFinishing={false}
    onContinue={() => {
      acknowledgeAccountDeletion();
      navigate("/sign-in", { replace: true });
    }}
  />;
}
