import { Suspense } from "react";

import { LoginForm } from "@/components/LoginForm";

/**
 * Email/password sign-in — deliberately different from the phone-OTP flow
 * in the consumer apps. Ops staff are internal employees with company
 * email accounts, not the phone-first elder/family/caregiver personas
 * this platform is designed around (PRD Part 1 §05).
 */
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-paper px-4">
      <Suspense>
        <LoginForm />
      </Suspense>
    </div>
  );
}
