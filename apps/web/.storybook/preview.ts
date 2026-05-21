// Storybook preview config (#57).
//
// Charge la CSS globale Tailwind (incluant les variables CSS du design
// system Piloo) pour que les composants s'affichent comme dans l'app.
import '../app/globals.css';

const preview = {
  parameters: {
    layout: 'centered',
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/,
      },
    },
    backgrounds: {
      default: 'piloo',
      values: [
        { name: 'piloo', value: '#F6F4F0' },
        { name: 'light', value: '#ffffff' },
        { name: 'dark', value: '#1F2A2A' },
      ],
    },
  },
};

export default preview;
