# GitHub Actions 证书配置与打包教程

## 第一部分：不需要任何证书也能看到"编译成功"

推送代码到 `main` 分支后，GitHub Actions 会自动跑 `build-and-test` 这个任务：
- 用 XcodeGen 生成 Xcode 工程
- 在模拟器上编译整个 App（不需要任何证书，`CODE_SIGNING_ALLOWED=NO`）
- 跑一遍单元测试

只要这一步显示绿色对勾 ✅，就说明代码本身没有问题，完全对应你确认的"F. 只需要 GitHub Actions 编译成功"。

**如果你只是想验证代码能不能编译，到这一步就够了，可以跳过下面的证书配置部分。**

---

## 第二部分（可选）：配置证书，产出真正能装到 iPhone 上的 IPA

你提到自己已经有"iOS 开发证书"和"Provisioning Profile"了，如果确实是最近生成、还没过期（免费账号证书只有 **7 天** 有效期！），可以直接跳到"3. 转换成 base64 并配置 Secrets"。如果已经过期或者没有，请从下面第 1 步开始，**全程不需要 Mac，用普通 Windows/Linux 电脑 + 浏览器就能完成**。

### 1. 用 OpenSSL 生成私钥和证书请求文件（CSR）

Windows 用户可以装 [Git for Windows](https://git-scm.com/download/win)，它自带的 Git Bash 里就有 `openssl` 命令。

```bash
# 生成一个私钥（务必妥善保管，不要泄露、不要提交到 GitHub）
openssl genrsa -out ios_distribution.key 2048

# 生成证书请求文件（CSR），邮箱和姓名填你自己的信息
openssl req -new -key ios_distribution.key -out CertificateSigningRequest.certSigningRequest \
  -subj "/emailAddress=你的Apple ID邮箱, CN=你的姓名, C=CN"
```

### 2. 用浏览器在 Apple Developer 后台生成证书

1. 打开 https://developer.apple.com/account/resources/certificates/list
2. 点击 "+" 新建证书，选择 "Apple Development"（免费账号只能选这个）
3. 上传第 1 步生成的 `CertificateSigningRequest.certSigningRequest`
4. 下载生成的 `.cer` 证书文件

### 3. 注册你的 iPhone（获取 UDID）

免费账号的证书/描述文件必须绑定具体设备的 UDID，才能安装使用。没有 Mac 的情况下获取 UDID 的几种方式：

- 用 **3uTools** 或 **iMazing**（Windows 版本也有，官网下载），USB 连接 iPhone 后就能看到 UDID
- 打开 iPhone 上的 Safari，访问 `udid.io` 之类的网站，按提示安装一个描述文件（会跳转到"设置 - 通用 - VPN与设备管理"），安装后网站会显示你的 UDID（选择你信任、口碑好的服务，安装前留意权限提示）
- 找一台朋友的 Mac 或者去 Apple 直营店，用"访达"连接查看

拿到 UDID 后：
1. 打开 https://developer.apple.com/account/resources/devices/list
2. 点击 "+"，把 UDID 填进去注册这台设备

### 4. 创建 App ID

1. 打开 https://developer.apple.com/account/resources/identifiers/list
2. 新建 App ID，Bundle ID 填 `com.bus.nailong`（要和 `ios/project.yml` 里的完全一致）
3. 按需勾选 Capabilities：至少不需要额外勾选什么特殊权限（本项目没有用到需要企业资质的能力）

### 5. 创建 Provisioning Profile（描述文件）

1. 打开 https://developer.apple.com/account/resources/profiles/list
2. 新建，类型选 "iOS App Development"
3. 选择上面创建的 App ID、证书、设备（你注册的那台 iPhone）
4. 下载生成的 `.mobileprovision` 文件

### 6. 用私钥 + 证书合成 .p12 文件

```bash
# 把苹果发的 cer 转成 pem
openssl x509 -in ios_development.cer -inform DER -out ios_development.pem -outform PEM

# 和第 1 步的私钥合成 p12，会提示你设置一个导出密码，记住它（这就是后面 Secrets 里的 P12_PASSWORD）
openssl pkcs12 -export -inkey ios_distribution.key -in ios_development.pem -out ios_development.p12
```

### 7. 把 p12 和 mobileprovision 转成 base64 文本

Windows（PowerShell）：
```powershell
certutil -encode ios_development.p12 p12_base64.txt
certutil -encode xxx.mobileprovision profile_base64.txt
```
打开生成的 txt 文件，去掉首尾的 `-----BEGIN CERTIFICATE-----` / `-----END CERTIFICATE-----` 这两行，剩下的内容就是要填进 Secrets 的值。

Mac / Linux：
```bash
base64 -i ios_development.p12 | tr -d '\n' > p12_base64.txt
base64 -i xxx.mobileprovision | tr -d '\n' > profile_base64.txt
```

### 8. 在 GitHub 仓库里配置 Secrets

打开你的仓库 → Settings → Secrets and variables → Actions → New repository secret，依次添加：

| Secret 名称 | 值 |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | 第 7 步生成的 p12 base64 内容 |
| `P12_PASSWORD` | 第 6 步设置的导出密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | 第 7 步生成的 mobileprovision base64 内容 |
| `KEYCHAIN_PASSWORD` | 随便设置一个新密码（比如一串随机字符），只是给 CI 临时用的 |
| `DEVELOPMENT_TEAM` | 你的 Team ID，在 https://developer.apple.com/account 页面右上角"Membership"里能看到，是一串 10 位字母数字 |

全部配置完成后，`archive-and-export` 这个任务就会自动开始运行（`ios-build.yml` 里判断这几个 Secrets 都不为空才会触发）。

### 9. 触发打包 & 下载 IPA

- 直接 `git push` 到 main 分支就会触发编译检查；如果 Secrets 配置好了，还会顺带产出 IPA
- 如果想创建一个正式的 Release 版本，打一个 tag：
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
  这会额外创建一个 GitHub Release，自动带上从上一个 tag 到现在的更新日志，并附上 IPA 文件
- 去仓库的 "Actions" 标签页，点进对应的运行记录，下方 "Artifacts" 里能下载 `BusTracker-ipa`

### 10. 把 IPA 装到 iPhone 上（没有 Mac 和 TestFlight 的情况下）

因为是免费账号 + development 签名（只能装到描述文件里注册过的设备），推荐：

- **Windows**：用 [Sideloadly](https://sideloadly.io/) 或 [3uTools](https://www.3u.com/)，USB 连接 iPhone，选择下载好的 ipa 文件，直接安装（因为 ipa 本身已经用正确的证书和描述文件签过名了，这些工具只是负责"传输安装"，不需要重新签名）
- 记得：免费账号签发的开发证书 **7 天后会失效**，到期后 App 会无法打开，需要重新走一遍上面的流程（这也是为什么将来升级付费账号会省很多事）

如果重新签名证书本身已过期，只需要重复第 1~7 步生成新的证书和 base64，更新 GitHub Secrets，重新触发一次 Actions 即可，不需要改任何代码。
