"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ADMIN_VIEW_COOKIE } from "@/lib/supabase/context";

export async function signOut() {
  const supabase = createClient();
  await supabase.auth.signOut();
  cookies().delete(ADMIN_VIEW_COOKIE);
  redirect("/login");
}
