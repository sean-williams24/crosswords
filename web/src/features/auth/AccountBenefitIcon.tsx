type AccountBenefitIconName = "sync" | "stats" | "pro";

type AccountBenefitIconProps = {
  name: AccountBenefitIconName;
};

export function AccountBenefitIcon({ name }: AccountBenefitIconProps) {
  return (
    <svg aria-hidden="true" className={`auth-benefit-icon auth-benefit-icon--${name}`} viewBox="0 0 24 24">
      {name === "sync" ? (
        <>
          <path d="M18.6 8.5A7.5 7.5 0 0 0 6.2 6.2L4 8.4" />
          <path d="M4 4.8v3.6h3.6" />
          <path d="M5.4 15.5a7.5 7.5 0 0 0 12.4 2.3l2.2-2.2" />
          <path d="M20 19.2v-3.6h-3.6" />
        </>
      ) : null}
      {name === "stats" ? (
        <path d="M4 20V11h3v9H4Zm6 0V4h3v16h-3Zm6 0v-7h3v7h-3Z" />
      ) : null}
      {name === "pro" ? (
        <path d="m3 7.5 4.1 3.3L12 4l4.9 6.8L21 7.5l-2.4 10H5.4L3 7.5ZM5 20h14v2H5v-2Z" />
      ) : null}
    </svg>
  );
}
