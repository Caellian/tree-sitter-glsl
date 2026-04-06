import treesitter from 'eslint-config-treesitter';

export default [
  {
    ignores: [
      '.claude/**',
      '!.claude/skills/*/examples/**',
      '.github/**',
      'bindings/**',
      'builtin.js',
      'specification/**',
      'src/**',
    ],
  },
  ...treesitter.map(config => ({
    ...config,
    files: config.files ?? ['**/*.js', '**/*.mjs'],
  })),
];
