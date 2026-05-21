import { Input } from '../input';
import { Label } from '../label';

const meta = {
  title: 'UI/Input',
  component: Input,
  args: {
    placeholder: 'maxime@exemple.fr',
  },
};

export default meta;

export const Default = {};

export const WithLabel = {
  render: () => (
    <div className="space-y-2 w-64">
      <Label htmlFor="email">Email</Label>
      <Input id="email" type="email" placeholder="maxime@exemple.fr" />
    </div>
  ),
};

export const Password = {
  args: { type: 'password', placeholder: '••••••••' },
};

export const Disabled = {
  args: { disabled: true, value: 'lecture seule' },
};
