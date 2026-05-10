# OptionRecorder

OptionRecorder 是一个本地 macOS 期权策略记账工具。它用 SwiftUI 构建桌面界面，用 SwiftData 持久化数据，核心目标是按策略记录每个标的的 Put / Call / 主动平仓交易、权利金收入、持股数量和调整后成本。

当前已实现 Wheel Strategy 记账规则，数据模型已带有策略维度，后续可以继续扩展 Covered Call、Cash-Secured Put 或其他期权策略的独立记账逻辑。正股价格获取已经抽象为 provider 机制，便于后续把价格预警接入到 UI。

## 功能

- 按股票代码和策略创建记账账本，代码会自动标准化为大写。
- 每个账本可设置一张期权对应的标的数量，默认 `100`，用于权利金和 assignment 计算。
- 当前策略支持 `Wheel`，核心分发层会按策略调用对应记账规则。
- 为持仓记录期权交易，支持 `Put`、`Call` 和 `Active Close` 三种操作类型。
- 记录每笔交易的行权价、权利金、到期日和状态。
- 支持 `Open`、`Assigned`、`Expired`、`Closed` 四种交易状态。
- Put 被标记为 `Assigned` 时，自动按账本设置的合约数量增加持股和股票成本。
- 从 `Assigned` 改回其他状态时，自动撤销对应的 Put assignment 持股和成本影响。
- 自动累计净权利金，并计算调整后持股成本；`Active Close` 会作为负向权利金现金流扣减净权利金。
- 正股价格获取已抽象为 `MarketPriceProvider`，当前预留 Yahoo Finance、Alpha Vantage 和 AkShare 三类来源。
- A 股 ticker 会被路由到 AkShare provider；Swift app 通过 `AKSHARE_PRICE_ENDPOINT` 指向本地或内网 AkShare HTTP bridge，不直接硬耦合 Python 运行时。
- 在侧栏展示整体账本数量、总股数、总权利金；在详情页展示单个策略账本指标和交易时间线。
- 支持删除持仓和交易；删除持仓会级联删除其交易记录。

## 当前状态

已完成：

- Wheel Strategy 账本创建、交易录入、状态流转和 assignment 记账。
- 多策略扩展基础：`OptionStrategy` + `OptionLedger` 策略分发层。
- App 入口和 target 名称为 `OptionRecoderApp`。
- 主动平仓类型 `Active Close`，按负向现金流扣减净权利金。
- 每个账本可配置一张期权对应的标的数量，默认 `100`。
- 正股价格 provider 抽象，支持按 ticker 市场类型路由到不同数据源。
- Core 测试和 macOS UI 自动化测试基础。

待接入 UI：

- 到期日历视图：聚合近期到期合约，优先展示下周五前需要处理的 open trades。
- 价格预警视图：拉取正股现价后，对现价低于 Put 行权价的合约做红色预警。

## 数据存储

应用使用 SwiftData，并将 SQLite 数据库固定保存到：

```text
~/Library/Application Support/OptionRecorder/OptionRecorder.sqlite
```

这是本地单机数据文件，便于备份、排查和后续迁移。

旧版本的 `WheelStrategy.sqlite` 如果存在，应用启动时会复制到新的 `OptionRecorder.sqlite` 路径，避免改名后丢失已有本地数据。

## 环境要求

- macOS 14 或更新版本
- Swift 6 toolchain

## 运行

在仓库根目录执行：

```bash
swift run OptionRecoderApp
```

应用窗口启动后，可以通过侧栏右上角新增 ticker 和策略，也可以使用 `Command + N` 新建账本。在持仓详情页填写交易信息后，使用 `Command + Return` 或页面按钮添加交易。

## 测试

运行核心业务逻辑测试：

```bash
swift test
```

如果本机 SwiftPM 用户级缓存权限受限，可以临时把 `HOME` 指向仓库内目录：

```bash
HOME="$PWD/.home" swift test --disable-sandbox
```

UI 自动化测试需要通过 Xcode UI test bundle 运行，不能使用 `swift test` 的 SwiftPM unit test bundle：

```bash
xcodebuild \
  -project OptionRecorder.xcodeproj \
  -scheme OptionRecoderApp \
  -destination 'platform=macOS' \
  -derivedDataPath .build/XcodeDerivedData \
  test
```

UI 测试会使用临时 SQLite 文件，不会写入用户真实的 `~/Library/Application Support/OptionRecorder/OptionRecorder.sqlite`。
在 Codex sandbox 中，macOS 会阻止连接 `com.apple.testmanagerd`，因此请在本机普通终端中执行上面的命令。

## 正股价格来源

正股价格获取通过 `MarketPriceProvider` 协议抽象，便于后续替换或新增数据源：

- `YahooFinancePriceProvider`：默认 global ticker 来源，不需要 API key。
- `AlphaVantagePriceProvider`：设置 `ALPHA_VANTAGE_API_KEY` 后会优先作为 global ticker 来源。
- `AkSharePriceProvider`：面向 A 股 ticker，设置 `AKSHARE_PRICE_ENDPOINT` 后启用。

默认 provider 注册顺序：

1. 如果配置了 `AKSHARE_PRICE_ENDPOINT`，A 股 ticker 走 AkShare。
2. 如果配置了 `ALPHA_VANTAGE_API_KEY`，global ticker 走 Alpha Vantage。
3. 未配置 Alpha Vantage 时，global ticker 走 Yahoo Finance。

AkShare provider 期望调用一个 HTTP bridge，例如：

```text
GET $AKSHARE_PRICE_ENDPOINT?symbol=600519
```

返回 JSON 至少包含 `price` 或 `latest_price`，可选 `symbol` 和 `currency`：

```json
{"symbol":"600519","price":1500.0,"currency":"CNY"}
```

Ticker 市场识别规则：

- `600519.SH`、`000001.SZ`、`000001` 这类 6 位 A 股代码识别为 A 股。
- `AAPL`、`MSFT`、`SPY` 等识别为 global ticker。

## 项目结构

```text
Sources/
  OptionRecoderApp/      SwiftUI 应用入口和界面
  WheelStrategyCore/     期权策略记账模型、策略分发和 Wheel 规则
Tests/
  WheelStrategyCoreTests/核心业务逻辑测试
  OptionRecoderAppUITests/主流程 UI 自动化测试
```

核心规则集中在 `WheelStrategyCore`：

- `OptionStrategy`：策略类型枚举，当前包含 `Wheel`。
- `Position`：标的、策略、合约数量、股数、股票成本、累计权利金和调整后成本。
- `OptionTrade`：单笔期权交易。
- `MarketPriceProvider`：正股价格来源抽象和 provider 路由。
- `OptionLedger`：面向 UI 的策略分发入口。
- `WheelLedger`：Wheel Strategy 的创建持仓、添加交易、更新状态及 assignment 记账逻辑。

## 验证状态

最近一次验证：

- `HOME="$PWD/.home" swift test --disable-sandbox`：10 个 core 测试通过。
- 本机 `xcodebuild ... test` UI 测试：已通过。
