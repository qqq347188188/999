# WB签到（iOS / TrollStore）

WorkBuddy / CodeBuddy「每日签到」的 iOS 客户端，复刻自开源项目
[`Luckyboy-daidai/wb-checkin-android`](https://github.com/Luckyboy-daidai/wb-checkin-android)。
针对 **已越狱的 iOS 16.6 + TrollStore** 环境打包为 IPA，零 Apple 证书、无需 App Store。

> 本项目为独立开发的第三方辅助工具，与 WorkBuddy / CodeBuddy 官方无关联，仅供学习研究使用。

---

## 一、功能清单（对照原项目）

| 功能 | 说明 | 对应原项目 |
| --- | --- | --- |
| 多账号管理 | 国内版（CodeBuddy/WorkBuddy）/ 国际版（WorkBuddy AI） | `AccountStore` |
| OAuth 登录 | 拉起授权页 → 状态轮询拿 Token → 拉取资料落库 | `LoginActivity` |
| 一键 / 自动每日签到 | 空体 POST 签到，按消息文本识别「已签到」幂等 | `Checkin` |
| 签到状态查询 | `today_checked_in` / 连续天数 | `checkin-activity-status` |
| 积分 / 额度查询 | 资源汇总、余额 | `CreditsActivity` |
| 派猫猫旅行 | `idle→派发 / arrived→领取 / traveling·已达上限→跳过` 状态机 | `Travel` |
| Token 惰性刷新 / 保活 | 距过期 <24h 自动刷新；可每日保活 | `TokenKeepAlive` |
| 签到日志 | 本地 JSON，最多 500 条 | `LogsActivity` |
| 导入 / 导出 | 与 Android / 桌面版 `accounts.json` 互通 | `ExportImport` |
| 本地通知提醒 | 每日定点提醒打开 App 补签 | — |
| 后台刷新 | `BGAppRefreshTask` 兜底 | — |

界面采用底部 5 个 Tab：**账号 / 签到 / 额度 / 日志 / 设置**，
「派猫猫旅行」作为卡片内嵌在「签到」页中。

---

## 二、依赖与接口（与原项目一致）

网络层严格模拟桌面客户端请求特征（`User-Agent`、特定请求头不可更改，否则网关拦截）：

- 国内版：`https://www.codebuddy.cn`（账号 `domain` 含 `workbuddy` 时走 `https://www.workbuddy.cn`）
- 国际版：`https://www.workbuddy.ai`
- 派猫猫旅行：`https://www.workbuddy.cn`（路径前缀 `/activity/growth/buddy/travel/`，**无 `/v2`**）

| 用途 | 方法 | 路径 |
| --- | --- | --- |
| 申请登录 | POST | `/v2/plugin/auth/state?platform=workbuddy\|workbuddy-ai` |
| 轮询令牌 | GET | `/v2/plugin/auth/token?state=...` |
| 拉取资料 | GET | `/v2/plugin/login/account?state=...` |
| 刷新令牌 | POST | `/v2/plugin/auth/token/refresh`（带 `X-Refresh-Token`） |
| 每日签到 | POST | `/v2/billing/meter/daily-checkin` |
| 签到状态 | POST | `/v2/billing/meter/checkin-activity-status` |
| 额度汇总 | POST | `/v2/billing/meter/get-user-resource-summary`（带 `X-Client-Platform: web`） |
| 旅行状态 | GET | `/activity/growth/buddy/travel/status` |
| 旅行地点 | GET | `/activity/growth/buddy/travel/config` |
| 派出旅行 | POST | `/activity/growth/buddy/travel/depart` `{"location_id":N}` |
| 领取奖励 | POST | `/activity/growth/buddy/travel/claim` `{}` |

> 签到 / 额度接口对国内版会依次尝试带 `/v2` 与不带 `/v2` 的候选路径；返回 404 则换下一个。

---

## 三、所需越狱环境 / 依赖项

- **iOS 16.6 已越狱**：Dopamine、palera1n 等任意 rootful/rootless 越狱均可。
- **TrollStore**（强烈推荐）：用于**零证书永久安装**本 IPA；CVE 利用安装方式不限。
- **无需任何额外插件 /  tweak**：本 App 仅做 HTTPS 网络请求，复刻桌面端 UA 与请求头，
  不依赖网络代理、不依赖证书绕过（服务端无证书绑定）。
- **后台自动签到**依赖：
  - 普通情况：`BGAppRefreshTask` 兜底刷新 + 本地通知每日提醒「打开 App 补签」；
  - 打开 App 时若当日未签会自动补签（默认开启）；
  - 若需要**真正无人值守**后台，可在越狱环境下用 `LaunchDaemons` 定时唤起本 App
    （本仓库默认未内置守护进程，可按需扩展）。

---

## 四、构建方式（零证书 IPA）

### 方式 A：GitHub Actions（推荐，无需本机 Mac）

1. 将本仓库推送到 GitHub；
2. 进入 **Actions → Build TrollStore IPA → Run workflow**，或打 `v*` 标签自动触发；
3. 构建产物 `wb-checkin-ios.ipa` 作为 Artifact 下载。

流程：`xcodegen` 生成 Xcode 工程 → `xcodebuild`（关闭签名 `CODE_SIGNING_ALLOWED=NO`，仅 `arm64`）
→ `codesign -s -` 做 ad-hoc 签名并嵌入 entitlements → 组装 `Payload/*.ipa`。

### 方式 B：本机 macOS 构建

```bash
brew install xcodegen
xcodegen generate
# 零证书直接打包（见 scripts/build.sh）
bash scripts/build.sh
```

`scripts/build.sh` 产物为未签名 + ad-hoc 签名的 `wb-checkin-ios.ipa`。

> 提示：若想用个人免费账号自签，可改用 `./scripts/build.sh --team-id <TEAM_ID>`。

---

## 五、安装方式

1. 获取 `wb-checkin-ios.ipa`（GitHub Actions Artifact 或本地构建）；
2. 通过 **TrollStore** 安装（分享到 TrollStore / 用 TrollStore 打开 IPA）；
3. 首次打开按提示添加账号：选择区域 → 开始登录 → 浏览器授权 → 点「检测登录」保存；
4. 之后在「签到」页一键签到，或开启「打开 App 自动补签」实现每日补签。

---

## 六、隐私说明

零收集设计：无注册、无统计 / 广告 SDK、无自有服务器。账号令牌仅存于 App 私有目录，
卸载即清除；所有网络请求仅发往官方域名。

---

## 七、工程结构

```
wb-checkin-ios/
├── project.yml                 # xcodegen 描述
├── Info.plist
├── wb-checkin-ios.entitlements # get-task-allow（TrollStore 友好）
├── scripts/build.sh            # 本地一键打包
├── .github/workflows/build-ipa.yml
└── Sources/
    ├── App.swift               # @main + AppDelegate（BGTask / 通知）
    ├── Models/                 # Account, LogEntry
    ├── Core/                   # APIClient, AccountStore, Logger, AppConfig, Tasks
    ├── Helpers/                # WebView, NotificationScheduler
    └── Views/                  # ContentView, Accounts, Login, Checkin, Travel, Credits, Logs, Settings
```

---

## 八、免责声明

仅供个人学习研究，请遵守 WorkBuddy / CodeBuddy 服务条款。勿将本工具用于商业或违规用途。
