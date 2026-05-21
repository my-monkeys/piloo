import { Button } from '../button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '../card';

const meta = {
  title: 'UI/Card',
  component: Card,
  parameters: { layout: 'padded' },
};

export default meta;

export const Default = {
  render: () => (
    <Card className="max-w-sm">
      <CardHeader>
        <CardTitle>Doliprane 1000mg</CardTitle>
        <CardDescription>
          Boîte ajoutée à votre officine Maison. Péremption dans 8 mois.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-sm">Reste 28 comprimés sur 30.</p>
      </CardContent>
      <CardFooter>
        <Button>Ouvrir</Button>
      </CardFooter>
    </Card>
  ),
};

export const Compact = {
  render: () => (
    <Card className="max-w-sm">
      <CardContent className="pt-6 text-sm text-muted-foreground">
        Active une officine depuis la sidebar pour voir tes prises du jour.
      </CardContent>
    </Card>
  ),
};
