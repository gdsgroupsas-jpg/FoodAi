'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { createBrowserSupabase } from '@/lib/db/browser';
import { Button } from '@/components/ui/button';
import {
  LayoutDashboard,
  Armchair,
  ChefHat,
  BookOpen,
  Warehouse,
  Truck,
  PieChart,
  Bot,
  LogOut,
  UtensilsCrossed,
} from 'lucide-react';

const navItems = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/dashboard/sala', label: 'Sala', icon: Armchair },
  { href: '/dashboard/cucina', label: 'Cucina', icon: ChefHat },
  { href: '/dashboard/ricette', label: 'Ricette', icon: BookOpen },
  { href: '/dashboard/magazzino', label: 'Magazzino', icon: Warehouse },
  { href: '/dashboard/fornitori', label: 'Fornitori', icon: Truck },
  { href: '/dashboard/food-cost', label: 'Food Cost', icon: PieChart },
  { href: '/dashboard/ai-assistant', label: 'AI Assistant', icon: Bot },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = createBrowserSupabase();

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  return (
    <div className="flex h-screen">
      {/* Sidebar */}
      <aside className="w-64 bg-gray-900 text-white flex flex-col">
        {/* Logo */}
        <div className="p-5 border-b border-gray-800">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-orange-500 rounded-lg flex items-center justify-center">
              <UtensilsCrossed className="w-5 h-5 text-white" />
            </div>
            <span className="text-lg font-bold">FoodCost AI</span>
          </div>
        </div>

        {/* Navigazione */}
        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {navItems.map((item) => {
            const isActive =
              item.href === '/dashboard'
                ? pathname === '/dashboard'
                : pathname.startsWith(item.href);
            const Icon = item.icon;

            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${
                  isActive
                    ? 'bg-orange-600 text-white font-medium'
                    : 'text-gray-300 hover:bg-gray-800 hover:text-white'
                }`}
              >
                <Icon className="w-5 h-5 shrink-0" />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Logout */}
        <div className="p-3 border-t border-gray-800">
          <Button
            variant="ghost"
            className="w-full justify-start text-gray-400 hover:text-white hover:bg-gray-800"
            onClick={handleLogout}
          >
            <LogOut className="w-5 h-5 mr-3" />
            Esci
          </Button>
        </div>
      </aside>

      {/* Contenuto principale */}
      <main className="flex-1 overflow-auto bg-gray-50">
        <div className="p-6">{children}</div>
      </main>
    </div>
  );
}
