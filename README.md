# IOTA 智慧家居 — Flutter App

區塊鏈智慧家庭系統的行動端，支援 Android / iOS / Web / Desktop。

> **這份是從主專案同步過來的副本。**
> App 的開發在主專案 [`alexchen9419/IOTA_API`](https://github.com/alexchen9419/IOTA_API)
> 的 `app/` 目錄進行，後端 API、MQTT 服務與 ESP32 韌體也都在那裡。
> 這個 repo 另外放了 `iota/`（區塊鏈的 UC5.x 工作），與 App 互不影響。

---

## 快速開始

### 情況 A：後端已經有人開著（最常見）

只要跑 App 就好：

```bash
flutter pub get
flutter run            # 接上的實機 / 模擬器
flutter run -d chrome  # 網頁版
```

App 啟動後在**登入頁底部**會顯示目前連線的後端位址。點它可以進「伺服器設定」
改成正確的位址，改完不用重新編譯。

填法：

| 你在哪裡跑 App | 填什麼 |
| :-- | :-- |
| 實體手機 | `http://<後端主機的區網IP>:8091`（例如 `http://192.168.50.234:8091`） |
| Android 模擬器 | `http://10.0.2.2:8091`（預設值，通常不用改） |
| 桌面 / Chrome，且後端在同一台 | `http://localhost:8091` |

按「測試連線」會打 `/healthz`，回 `{"status":"ok"}` 就是通了。

> **實體手機必須與後端主機在同一個網段。** 手機開熱點給自己、電腦卻接在別的
> 網路，一定連不上。

### 情況 B：要自己把後端也起起來

後端不在這個 repo，要先把主專案抓下來：

```bash
git clone https://github.com/alexchen9419/IOTA_API.git
cd IOTA_API

# 本機開發用（MQTT 走明文 1883）
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 確認起來了
curl http://localhost:8091/healthz     # 要回 {"status":"ok"}
docker compose ps                      # 七個容器都要是 Up
```

起來的服務：

| 服務 | 埠 | 用途 |
| :-- | :-- | :-- |
| `iot_api` | 8091 | API 閘道，**App 打這個** |
| `iot_mysql` | 3306 | 資料庫 |
| `mqtt_service` | 1883 / 8883 / 9001 | MQTT broker（明文 / TLS / WebSocket） |
| `mqtt_server` | 8080 | 裝置註冊、OTA 韌體伺服器 |
| `mqtt_monitor` | 8090 | 裝置狀態網頁監控 |
| `iot_api_mqtt_bridge` | — | API 與韌體之間的 topic 轉譯 |
| `node_red` | 1880 | 流程編輯 |

> **為什麼用 `docker-compose.dev.yml`**：正式的 `mosquitto.conf` 是 TLS-only
> （8883），需要 `config/certs/server.key`，而那支私鑰依 `.gitignore` 不進版控。
> clone 下來的機器沒有它，mosquitto 起不來。dev 設定改走明文 1883，不動任何
> 既有設定或憑證。

關閉：

```bash
docker compose down        # 保留資料
docker compose down -v     # 連資料庫一起清掉
```

---

## 測試帳號

密碼都是 `Test1234!`

| 帳號 | 角色 | 看得到什麼 |
| :-- | :-- | :-- |
| `itadmin047698` | 場域 4 Admin | 完整權限：三個分頁、管理選單、訪客 QR、配對裝置 |
| `itmember047698` | 場域 4 Member | 能控制裝置，但沒有管理選單與邀請分頁 |

沒有帳號就在登入頁點「立即註冊」，再請 Admin 發邀請。

---

## 專案結構

```
lib/
├─ main.dart                  啟動；先讀回伺服器位址與登入狀態才進第一個畫面
├─ screens/
│  ├─ login / register        登入註冊
│  ├─ family_list             場域清單與邀請通知
│  ├─ family_detail           成員 / 裝置 / 發送邀請，標題列可切換場域（UC1.5）
│  ├─ dashboard               場域儀表板：狀態、連線健康度、遙測歷史（UC4.3）
│  ├─ guest_qr                訪客臨時授權 QR（UC3.4）
│  └─ server_settings         後端位址設定
├─ widgets/
│  ├─ device_card             裝置卡片
│  ├─ device_control_sheet    遠端控制面板（UC4.1）
│  └─ device_admin_dialogs    配對 / 維修模式 / 韌體更新 / 除役
└─ utils/
   ├─ api_client              所有 API 呼叫的單一入口
   ├─ api_config              後端位址解析與端點常數
   ├─ session                 登入狀態保存
   ├─ parsing                 防禦性解析，後端型別不一致時不會讓畫面崩掉
   └─ device_models           裝置型號，與主專案 mqtt-server/models.yaml 對齊
```

---

## 卡住時

| 症狀 | 原因 |
| :-- | :-- |
| 登入跳「連不上伺服器」 | 後端沒開，或位址填錯。先用瀏覽器開 `http://<IP>:8091/healthz` 確認 |
| 登入成功但場域清單是空的 | 這個帳號還沒加入任何場域。自己建一個，或請 Admin 發邀請（**對方要按接受才算數**） |
| 場域裡看不到裝置 | 裝置要先在 App 做過「配對裝置」才會進資料庫。**韌體自己註冊不算**——那只會寫進 mqtt-server 的 `devices.json`，兩套系統沒有自動同步 |
| 點裝置卡片沒反應 / 跳權限說明 | 你的角色沒有控制權限（Guest 不能控制），請 Admin 調整 |
| 按解鎖後 30 秒跳「裝置沒有回報狀態」 | 沒有實體裝置在線，或 MAC 與配對時填的不一致 |
| 網頁版被 CORS 擋掉 | 確認打的是 `:8091` 的 API 閘道，不是其他服務 |

主專案裡有診斷工具：

```bash
python tools/diagnose_devices.py        # 裝置為什麼讀不出來
python mqtt-server/fake_device.py <MAC> # 沒有硬體時模擬一台裝置
```

還有一個開發觀測台 `tools/console/`，可以看到 MQTT 上實際流過的封包，
用來確認「手機送出的指令到底斷在哪一段」。

---

## 開發

```bash
flutter analyze    # 應該 0 issues
flutter test       # 40 個測試
```

`test/device_models_test.dart` 會去讀主專案的 `mqtt-server/models.yaml` 比對
裝置型號。單獨 clone 這個 repo 時拿不到那個檔案，該項會自動跳過。

已知待辦：套件名稱仍是 Flutter 範本的 `my_app`，改名要連 import 一起處理。
