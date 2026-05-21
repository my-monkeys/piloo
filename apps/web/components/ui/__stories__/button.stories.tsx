import { Button } from '../button';

const meta = {
  title: 'UI/Button',
  component: Button,
  args: {
    children: 'Cliquer',
  },
  argTypes: {
    variant: {
      control: 'select',
      options: ['default', 'destructive', 'outline', 'secondary', 'ghost', 'link'],
    },
    size: {
      control: 'select',
      options: ['default', 'sm', 'lg', 'icon'],
    },
    disabled: { control: 'boolean' },
  },
};

export default meta;

export const Default = {};

export const Destructive = {
  args: { variant: 'destructive', children: 'Supprimer' },
};

export const Outline = {
  args: { variant: 'outline' },
};

export const Ghost = {
  args: { variant: 'ghost', children: 'Annuler' },
};

export const Disabled = {
  args: { disabled: true, children: 'Désactivé' },
};
