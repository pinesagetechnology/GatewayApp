# React TypeScript Boilerplate (No react-scripts)

A modern React application built with TypeScript and Webpack 5, without using Create React App or react-scripts. This gives you full control over your build configuration and dependencies.

## 🚀 Features

- ⚛️ **React 18** with modern hooks and patterns
- 🔷 **TypeScript** with strict mode and proper typing
- 📦 **Webpack 5** with custom configuration
- 🔥 **Hot Module Replacement** for fast development
- 🎨 **Modern CSS** with responsive design
- 📱 **Mobile-responsive** layout
- 🧪 **ESLint** + **TypeScript ESLint** for code quality
- 🗺️ **Source maps** for debugging
- 📁 **Path aliases** (`@/` for `src/`)

## 🛠️ Tech Stack

- **Frontend**: React 18, TypeScript
- **Build Tool**: Webpack 5
- **Development Server**: webpack-dev-server
- **Linting**: ESLint + TypeScript ESLint
- **Styling**: CSS with modern features

## 📋 Prerequisites

- Node.js (version 16 or higher)
- npm or yarn

## 🚀 Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Development

Start the development server with hot reload:

```bash
npm start
```

This will:
- Start the dev server on `http://localhost:3000`
- Open your browser automatically
- Enable hot module replacement
- Provide source maps for debugging

### 3. Build for Production

```bash
npm run build
```

This creates an optimized build in the `dist/` folder.

### 4. Development Build

```bash
npm run build:dev
```

Creates a development build with source maps.

## 📁 Project Structure

```
├── public/
│   └── index.html          # HTML template
├── src/
│   ├── App.tsx             # Main application component
│   ├── App.css             # Component styles
│   ├── index.tsx           # Application entry point
│   └── index.css           # Global styles
├── webpack.config.js       # Webpack configuration
├── tsconfig.json           # TypeScript configuration
├── .eslintrc.js            # ESLint configuration
├── package.json            # Dependencies and scripts
└── README.md               # This file
```

## ⚙️ Configuration Files

### Webpack (`webpack.config.js`)
- Entry point: `src/index.tsx`
- Output: `dist/` folder
- Loaders: TypeScript, CSS, assets
- Development server with HMR
- Source maps and optimization

### TypeScript (`tsconfig.json`)
- Strict mode enabled
- Modern ES2020 target
- Path aliases (`@/` for `src/`)
- Declaration files generation

### ESLint (`.eslintrc.js`)
- TypeScript-aware linting
- React and React Hooks rules
- Customizable rule set

## 🎯 Available Scripts

- `npm start` - Start development server
- `npm run build` - Build for production
- `npm run build:dev` - Build for development
- `npm run type-check` - Type check without building
- `npm run lint` - Run ESLint
- `npm run lint:fix` - Fix ESLint issues automatically

## 🔧 Customization

### Adding New Loaders
Edit `webpack.config.js` and add new rules to the `module.rules` array.

### TypeScript Paths
Modify `tsconfig.json` to add more path aliases.

### ESLint Rules
Customize `.eslintrc.js` to match your coding standards.

## 🌟 What's Different from Create React App?

1. **No react-scripts dependency** - Full control over build process
2. **Custom webpack configuration** - Optimize for your needs
3. **Smaller bundle size** - Only include what you need
4. **Faster builds** - Webpack 5 with modern optimizations
5. **Flexible configuration** - Easy to modify and extend

## 🐛 Troubleshooting

### TypeScript Errors
Run `npm run type-check` to see TypeScript compilation errors.

### Linting Issues
Run `npm run lint:fix` to automatically fix most ESLint issues.

### Build Issues
Check that all dependencies are installed: `npm install`

## 📚 Learning Resources

- [Webpack Documentation](https://webpack.js.org/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [React Documentation](https://react.dev/)
- [ESLint Rules](https://eslint.org/docs/rules/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Happy coding! 🎉**
