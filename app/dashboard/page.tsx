import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Armchair, BookOpen, Warehouse, PieChart } from 'lucide-react';

const quickLinks = [
  {
    title: 'Sala',
    description: 'Gestisci tavoli e comande',
    icon: Armchair,
    href: '/dashboard/sala',
    color: 'bg-green-100 text-green-700',
  },
  {
    title: 'Ricette',
    description: 'Menu e distinte base',
    icon: BookOpen,
    href: '/dashboard/ricette',
    color: 'bg-blue-100 text-blue-700',
  },
  {
    title: 'Magazzino',
    description: 'Stock, scadenze, carico merci',
    icon: Warehouse,
    href: '/dashboard/magazzino',
    color: 'bg-purple-100 text-purple-700',
  },
  {
    title: 'Food Cost',
    description: 'Margini e analytics',
    icon: PieChart,
    href: '/dashboard/food-cost',
    color: 'bg-orange-100 text-orange-700',
  },
];

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 mt-1">
          Benvenuto in FoodCost AI. Seleziona una sezione per iniziare.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {quickLinks.map((link) => {
          const Icon = link.icon;
          return (
            <a key={link.href} href={link.href}>
              <Card className="hover:shadow-md transition-shadow cursor-pointer h-full">
                <CardHeader className="pb-3">
                  <div
                    className={`w-10 h-10 rounded-lg flex items-center justify-center ${link.color}`}
                  >
                    <Icon className="w-5 h-5" />
                  </div>
                </CardHeader>
                <CardContent>
                  <CardTitle className="text-base">{link.title}</CardTitle>
                  <CardDescription className="mt-1">{link.description}</CardDescription>
                </CardContent>
              </Card>
            </a>
          );
        })}
      </div>
    </div>
  );
}
