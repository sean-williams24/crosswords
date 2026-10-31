import type { ReactNode } from "react";
import { useLocation } from "react-router-dom";
import { brand, isLegacyOrigin } from "../brand/brand";
import { DomainMigrationPage } from "./DomainMigrationPage";

export function LegacyMigrationGate({ children }: { children: ReactNode }) {
  const { pathname } = useLocation();
  const handlesAuthentication = pathname === "/auth/callback" || pathname === "/sign-in";
  return brand.launchEnabled && isLegacyOrigin(window.location.origin) && !handlesAuthentication
    ? <DomainMigrationPage /> : children;
}
