'use client';

import { FormEvent, useState } from "react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "../../lib/supabase/client";

export default function Signup() {
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [username,setUsername]=useState("");
  const [displayName,setDisplayName]=useState("");
  const [message,setMessage]=useState("");
  const [busy,setBusy]=useState(false);

  async function submit(event:FormEvent<HTMLFormElement>) {
    event.preventDefault(); setMessage(""); setBusy(true);
    try {
      const supabase=createSupabaseBrowserClient();
      const {data,error}=await supabase.auth.signUp({email,password,options:{data:{username,display_name:displayName}}});
      if(error) throw error;
      if(data.session) setMessage("Account created. You are signed in.");
      else setMessage("Check your email to confirm your account, then log in.");
    } catch(error) { setMessage(error instanceof Error?error.message:"Could not create account."); }
    finally { setBusy(false); }
  }

  return <main className="auth-page"><Link href="/" className="brand">MOMENT</Link><section className="auth-card"><p className="eyebrow">START WITH A MOMENT</p><h1>Create your account</h1><p className="auth-intro">Set up your profile to host and join shared experiences.</p><form onSubmit={submit} className="auth-form"><label>Display name<input value={displayName} onChange={e=>setDisplayName(e.target.value)} required maxLength={60} autoComplete="name"/></label><label>Username<input value={username} onChange={e=>setUsername(e.target.value)} required minLength={3} maxLength={24} pattern="[A-Za-z0-9_]+" autoComplete="username"/></label><label>Email<input type="email" value={email} onChange={e=>setEmail(e.target.value)} required autoComplete="email"/></label><label>Password<input type="password" value={password} onChange={e=>setPassword(e.target.value)} required minLength={8} autoComplete="new-password"/></label><button className="button button-dark" disabled={busy}>{busy?"Creating account…":"Create account"}</button></form>{message&&<p role="status" className="form-message">{message}</p>}<p className="auth-foot">Already have an account? <Link href="/login">Log in</Link></p></section></main>;
}