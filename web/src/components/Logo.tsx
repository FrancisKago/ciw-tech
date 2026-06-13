/** Logo Cameroon Innovation. variant="mark" (écusson) ou "lockup" (avec wordmark). */
export default function Logo({
  variant = "mark",
  className,
}: {
  variant?: "mark" | "lockup";
  className?: string;
}) {
  const src = variant === "lockup" ? "/brand/logo_lockup.svg" : "/brand/logo_mark.svg";
  const dims = variant === "lockup" ? { width: 180, height: 56 } : { width: 36, height: 36 };
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={src} alt="Cameroon Innovation" {...dims} className={className} />
  );
}
