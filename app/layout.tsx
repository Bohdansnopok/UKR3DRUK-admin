import type { Metadata } from "next"; import "./globals.css";import "./mutations.css";
export const metadata: Metadata = { title:"UKR3DRUK Admin", description:"Спільна виробнича адмін-панель" };
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="uk"><body>{children}</body></html>}
