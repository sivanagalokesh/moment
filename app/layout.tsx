import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "MOMENT — Find your people. Share your moment.", description: "A privacy-first virtual activity and collaboration platform." };
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>;}