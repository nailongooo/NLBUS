# 出行提醒（类掌上公交）

一个类似"掌上公交"的出行到站提醒系统：选择公交路线或自定义路线，开始行程后根据你的实时位置，
在预提醒 / 即将到站 / 到站 三个阶段分别提醒你，并支持上车提醒、坐过站检测、众包车辆位置。

**先看 [`docs/00-项目总览.md`](docs/00-项目总览.md)，里面有完整的上手顺序说明。**

## 目录结构

```
transit-tracker/
├── ios/              iOS App 源码（SwiftUI + XcodeGen，零第三方依赖）
├── backend/          后端服务（Node.js + Express + MySQL）
├── admin-web/         网页版管理后台（纯静态 HTML/JS）
├── .github/workflows  GitHub Actions：免证书编译检查 + 可选签名打包 IPA
└── docs/              详细的中文教程文档
```

## 快速上手

1. `docs/01-新手环境准备.md` —— 确认你需要准备哪些账号/工具（不需要 Mac）
2. `docs/03-后端部署教程.md` —— 把后端部署到你自己的服务器
3. 把 `ios/App/Services/APIClient.swift` 和 `admin-web/js/api.js` 里的 `YOUR_DOMAIN_HERE` 换成你的真实域名
4. 把整个项目 `git push` 到你的 GitHub 私有仓库，Actions 会自动开始编译检查
5. （可选）`docs/02-GitHubActions证书打包教程.md` —— 配置签名证书，产出真正能装机的 IPA

## 重要的诚实说明

- 这批代码是在没有 Mac / Xcode 的环境下编写的，经过了仔细的人工审查，但**没有经过真实的 `xcodebuild` 编译验证**。
  第一次真正的编译发生在你推送到 GitHub 之后，由 Actions 里的云端 Mac 完成。如果报错，把日志发给开发者/AI 助手可以继续排查修复。
- 车辆实时位置使用"众包"方案（乘车用户匿名上报位置），不依赖任何第三方地图公司的公交数据接口。
- 免费 Apple 开发者账号的能力边界（证书 7 天有效期、无法用 TestFlight 正式分发）已经在代码和文档里如实说明。

## License

个人学习 / 毕业设计用途，无特殊限制。
