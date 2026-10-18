/**
 * React Native CLI 配置。
 *
 * 本库基于 Nitro Modules，原生注册由 Nitro 的 autolinking 自动完成，无需在
 * `react-native.config.js` 中声明 TurboModule / ReactPackage。这里仅保留原生工程
 * 目录的声明，供 CLI 正确定位 `android/` 与 `ios/` 源码。
 *
 * @type {import('@react-native-community/cli').Config}
 */
module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: 'android',
      },
      ios: {
        sourceDir: 'ios',
      },
    },
  },
};
