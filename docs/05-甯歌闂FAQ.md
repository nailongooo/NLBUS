# 常见问题 FAQ

### Q-2：报错 "Unable to find a device matching the provided destination specifier... name:iPhone 16"？
这也是我这边的问题（已修复），记录一下：我最初在跑单元测试的步骤里写死了模拟器型号名 `iPhone 16`，
但苹果每次更新 Xcode 模拟器镜像，默认自带的机型阵容都可能变化——你这次遇到的 Xcode 26.5 镜像上
已经没有单独的"iPhone 16"了（换成了 iPhone 16e / 17 / 17 Pro / 17 Pro Max / 17e / Air 这些）。

现在改成运行时动态查询"当前镜像里实际有哪些可用的 iPhone 模拟器"，自动选一个（优先选普通数字型号，
比如 iPhone 17，避开 Pro/Pro Max/Air/e 这些变体），不再写死具体型号名，这样以后镜像再怎么更新
也不会因为型号名对不上而失败。对应的脚本在 `.github/scripts/pick_simulator.py`。

### Q-1：日志里出现 "Pattern does not match any files" 和 "403 Resource not accessible by integration"？
这是我这边工作流文件里的两个真实 bug（已修复），记录一下方便理解：

1. **`|| true` 把真实的编译失败也吞掉了**。我最初在每个 `xcodebuild ... | xcbeautify` 命令后面加了 `|| true`，
   本意是"防止 xcbeautify 这个格式化小工具没装导致误报失败"，但这样写会导致**不管 xcodebuild 本身是真失败
   还是真成功，这一步永远显示成功**。所以哪怕 Archive 或者 Export IPA 那一步实际上出错了、没有真正产出
   IPA 文件，日志里也看不出来，一直到最后 "上传/创建 Release" 那一步才会因为找不到 ipa 文件报错。
   现在已经去掉了这个 `|| true`，`xcodebuild` 真实的成功/失败会如实反映在每一步上。
2. **创建 GitHub Release 报 403**：默认情况下 `GITHUB_TOKEN` 只有只读权限，创建 Release、上传 Release 附件
   需要写权限。现在已经在工作流文件顶部加上：
   ```yaml
   permissions:
     contents: write
   ```
   来解决这个问题。

修复之后重新跑一次，如果 Archive 或 Export IPA 那一步第一次真正报错，把具体报错内容发我，这时候看到的
才是关于签名/证书配置的真实问题（比如 Bundle ID 不匹配、描述文件没包含这台设备等），我可以针对性帮你解决。

### Q0：报错 "Unrecognized named-value: 'secrets'"，Actions 一启动就秒失败？
这是我最初给的 `ios-build.yml` 里的一个真实 bug（已修复），记录在这里方便你以后遇到类似问题时理解原因：
GitHub Actions **不允许在"job 级别的 `if:`"里直接判断 `secrets.xxx != ''`**，这是 GitHub 的硬性限制——job 级别
的 `if` 在 runner 分配之前就要求值，此时 secrets 还没有被注入进这次运行的上下文，所以直接引用会导致
**整个工作流文件被判定为不合法**，进而所有 job（包括根本不需要证书的编译检查）都无法运行，
表现出来就是"一启动就秒失败"。

正确写法是用一个单独的、跑在 `ubuntu-latest`（不额外计费 macOS 分钟数）上的 `check-secrets` job，
在它的"步骤内部"（`steps` 而不是 job 的 `if`）读取 secrets 并输出一个普通的 `true`/`false` 字符串，
下游的 `archive-and-export` job 再通过 `needs.check-secrets.outputs.has-signing == 'true'` 来判断——
`needs.*.outputs` 是 GitHub 官方明确支持在 job 级别 `if:` 里使用的写法。现在的 `ios-build.yml` 已经是
这个正确写法了。

### Q1：GitHub Actions 报错了怎么办？
把 Actions 运行记录里报红的那一步的完整日志复制给我（不需要整个日志，找到第一处 `error:` 或者
`** BUILD FAILED **` 附近的内容即可），我可以帮你分析具体原因。iOS 项目第一次真正编译是在 Actions
里完成的，出现一些小问题需要来回调整是正常的。

### Q2：为什么我的开发证书过期了，IPA 装不上？
免费 Apple 开发者账号签发的 "Apple Development" 证书有效期只有 7 天。过期后需要重新走一遍
`02-GitHubActions证书打包教程.md` 里第 1~7 步生成新证书，更新 GitHub Secrets，无需改动代码。
如果这个问题让你觉得很麻烦，可以考虑升级到 99 美元/年的付费开发者账号，证书有效期会延长到 1 年。

### Q3：为什么"公交实时到站"没有官方数据？
个人开发者很难拿到高德/百度地图的公交实时数据授权（通常需要企业资质审核）。本项目采用"众包"方案：
正在乘车的用户会匿名上报位置，服务器聚合展示给同一条路线上的其他乘客。这意味着：一条路线如果最近没有
其他人在乘车上报，就暂时不会显示"实时车辆位置"，这是数据来源的天然限制，不是 bug。

### Q4：为什么锁屏之后"到站响铃"不像闹钟一样一直响？
iOS 系统限制普通 App 不能在后台无限期播放声音（这项能力叫 Critical Alerts，需要向 Apple 单独申请特殊权限，
门槛很高）。本项目的做法是：App 在前台时循环响铃直到你手动点击停止；后台/锁屏时连续发送几条间隔几秒的
通知作为折中方案。

### Q5：想把地图从 Apple 地图换成高德地图，怎么做？
目前 `MapContainerView.swift` 用的是苹果原生 MapKit，不需要任何 API Key，打包风险最低。如果你想换成高德，
需要：申请高德开放平台的 iOS SDK Key、用 CocoaPods 或 SPM 引入高德 SDK、把 `MapContainerView.swift` 里
的 `Map` 相关代码换成高德的 `MAMapView`（一般需要包一层 UIViewRepresentable）。这部分改动量不小，
建议先把当前版本跑通之后再考虑升级。

### Q6：为什么后端要用众包位置而不是直接接入公交公司的数据？
除非你能和当地公交集团谈下数据合作（这在个人项目/毕业设计阶段通常不现实），众包是唯一不需要额外资质、
成本最低的技术方案，也是"掌上公交"类 App 早期版本常用的思路。

### Q7：App 图标是空的？
是的，`ios/App/Resources/Assets.xcassets/AppIcon.appiconset` 目前只有配置文件，没有真正的图标图片，
这是因为我这边没法帮你设计一张真正的图标。运行起来图标会显示系统默认样式（不影响编译和使用），
你可以之后自己设计一张 1024x1024 的 PNG 图片，替换到这个目录里（可以用 Figma、Canva 或者直接让我
帮你生成一版 SVG 图标再转 PNG）。

### Q8：以后想加"多日历/多种交通方式"的完整 GTFS 支持怎么办？
`backend/src/utils/gtfsImport.js` 目前只处理了每条 GTFS route 的"第一趟班次"作为代表性站序，
足够覆盖大多数公交路线的场景，但没有处理 GTFS 里更复杂的日历（calendar.txt）、多方向 trip 等情况。
这是有意为之的简化，避免第一版就陷入 GTFS 规范的复杂细节里，可以后续按需扩展。
