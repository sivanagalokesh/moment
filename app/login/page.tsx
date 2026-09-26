'use client';

import { FormEvent, useState } from "react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "../../lib/supabase/client";

export default function Login() {
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [message,setMessage]=useState("");
  const [busy,setBusy]=useState(false);

  async function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault(); setMessage(""); setBusy(true);
    try {
      const supabase=createSupabaseBrowserClient();
      const {error}=await supabase.auth.signInWithPassword({email,password});
      if(error) throw error;
      window.location.assign("/app");
    } catch(error) { setMessage(error instanceof Error?error.message:"Could not log in."); }
    finally { setBusy(false); }
  }
  return <main className="auth-page"><Link href="/" className="brand">MOMENT</Link><section className="auth-card"><p className="eyebrow">WELCOME BACK</p><h1>Log in</h1><p className="auth-intro">Pick up where your people left off.</p><form onSubmit={submit} className="auth-form"><label>Email<input type="email" value={email} onChange={e=>setEmail(e.target.value)} required autoComplete="email"/></label><label>Password<input type="password" value={password} onChange={e=>setPassword(e.target.value)} required autoComplete="current-password"/></label><button className="button button-dark" disabled={busy}>{busy?"Logging in…":"Log in"}</button></form>{message&&<p role="status" className="form-message">{message}</p>}<p className="auth-foot"><Link href="/forgot-password">Forgot password?</Link></p><p className="auth-foot">New to MOMENT? <Link href="/signup">Create an account</Link></p></section></main>;
}