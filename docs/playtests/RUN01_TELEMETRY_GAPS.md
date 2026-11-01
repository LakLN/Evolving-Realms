# Run 01 — Khoảng trống telemetry và Event Journal đề xuất

Trạng thái: **thiết kế đề xuất, chưa triển khai**. Không đổi save schema, gameplay, exporter hoặc dữ liệu cá nhân trong task này. [Summary](RUN01_SUMMARY.md) ghi số liệu đã xác minh; [Improvements](RUN01_IMPROVEMENTS.md) xếp ưu tiên.

## 1. Công cụ hiện có làm được gì

`RunTelemetry.build` đọc một saved Run, không ghi event liên tục. Nó có World/Run seed, spawn, turn/status, progression, resource snapshot, danh sách talent/skill, location discovery/resolution và số creature mutation dead. Các trường không biết như duration/attempts/wins/losses/death cause có `available=false`, không phải0.

`milestones` là tập hợp record còn tồn tại (creation, skill learning, talent awakening, location discovery/resolution). Nó không phải event journal đầy đủ và không được mặc định coi là timeline đã sắp xếp theo turn. Một số trường turn đủ để dựng **timeline cục bộ của nhánh còn lưu**.

SQL read-only bổ sung inventory, gear, definition được pin, entity mutations, fog và Region Ledger. Những dữ liệu này đủ mô tả nhân vật hiện tại; không biến thành lịch sử chỉ bằng cách nối nhiều bảng.

## 2. Điều biết được và phần còn thiếu

| Câu hỏi | Có bằng chứng hiện tại | Chưa biết / không được suy diễn |
|---|---|---|
| Tiến độ đến đâu? | turn3297, level10, XP dư121; turn học11skill | thời điểm từng level, XP theo nguồn, XP đã mất vì rollback, tốc độ/giờ |
| Đã đánh thắng bao nhiêu? | 44 distinct saved dead creature;11species | số trận, attempt, thắng/thua, ai kết liễu, các kill bị rollback |
| Chết do đâu? | Người chơi xác nhận Bleed turn68 | DB không ghi nguyên nhân, nguồn áp status, damage cuối, HP trước hit hoặc save đã load lại |
| Hồi Khí có hiệu quả? | Talent C đang có; người chơi thấy kích hoạt; luật heal/cooldown | `state={}` không có saved proc count; không có actual heal, overheal, lần cứu sống; không kết luận chưa từng proc |
| Có counter nào không? | Triggered skill `first_blood.used=25`; Stoneskin cooldown_until1452 | counter chỉ theo cơ chế/nhánh lưu; không phải tổng mọi skill/talent hay journal mọi lần cast |
| Sinh tồn có áp lực? | Hunger845/thirst319, lượng food/water còn lại | lượt từng ở warning/danger/depleted, item dùng/bị cap, nguồn/thời điểm replenish, death do starvation |
| Loot/gear có hấp dẫn? | Inventory/gear hiện tại; receipt của object/creature/place; metadata nguồn item còn giữ | toàn bộ loot nhận/tiêu/thay/bỏ, thời gian tới upgrade, lựa chọn bị từ chối, đánh giá người chơi |
| Skill có được dùng? | Learned record có turn, một số cooldown/counter | successful/failed casts cho mọi skill, cost/impact thực, combo frequency, lý do không dùng |
| Place có đa dạng? | 5 discovered record, mỗi nơi có1 interaction giải quyết | time-to-discovery, nhánh chance đã chạy, heal/status/XP thực nhận sau cap, nơi nhìn thấy nhưng không discover |
| Đã đi bao xa? | 26.576 visible-ever tiles/77 touched fog chunks, biome suy ra | route, movement count, số lần qua biome, khoảng trống giữa POI, số chunk nhìn thấy toàn bộ |
| Chơi bao lâu? | creation timestamp, turn | active play duration, số session, pause/menu/idle time; elapsed since creation không phải playtime |
| AI dùng thế nào? | Definition public provenance, learned/equipped/dead/place state | nội dung được đọc/nhận biết, mức mới lạ, user satisfaction; installed không phải encountered |

Normal Mode không lưu death-state. Rollback có thể đưa HP, inventory, fog, talent counter và turn về checkpoint cũ. Vì vậy không cộng một death được người chơi kể vào DB kill/loss counter rồi trình bày thành tổng đã xác minh. Tách `player_reported` khỏi `observed_journal` và `saved_snapshot`.

## 3. Giới hạn của exporter cần ghi rõ

- `survival_snapshot.stats.max_hp` là **base lưu**, không phải effective max HP. R01 có HP36, base max30 nhưng effective max69; không đánh dấu save lỗi chỉ vì36>30. ATK/DEF, inventory và explored tile count cũng cần tính/bổ sung riêng để trả lời retrospective.
- Creature-dead là entity-state count, không phải combat win count hoặc lifetime kill count. Location `received=[]` không ghi lại mọi effect hoặc random branch.
- Một số talent/trigger đã có state counter, một số record rỗng. Không viết một quy tắc “game hoàn toàn không lưu proc” hoặc chuyển missing thành0 lịch sử.
- CLI exporter mở adapter có khả năng ghi và có kiểm tra schema, **không cam kết SQLite read-only**. Task này khắc phục ở quy trình bằng cách mở DB cá nhân `mode=ro/query_only`, backup ra bản sao rồi chỉ export bản sao. Tương lai nên có đường export read-only thật và redaction option; chưa sửa code ở đây.
- Raw report có full IDs/seed/timestamp. Giữ cục bộ, không commit hoặc gửi mặc định. Số liệu phân tích đã ẩn định danh phải vẫn ghi source/giới hạn.

## 4. Event Journal tối thiểu đề xuất

### Phạm vi

Một file JSONL append-only cục bộ, theo Run/phiên, nằm ngoài save gameplay; không service, network, database telemetry mới hoặc framework event bus. Hook vào kết quả action/effect **đã commit thành công** và các điểm session/save/death sẵn có. Không log từng bước di chuyển, mỗi ô fog hoặc mỗi frame.

Trường chung dự kiến:

- `journal_schema`, `event_id`, `session_id`, `attempt_id`, sequence tăng trong phiên, `action_id` để nối các effect của cùng action.
- Run ID cục bộ, World ID cục bộ, build/rules version; không cần raw seed, username, đường dẫn máy, prompt hoặc API key.
- UTC event timestamp để sắp xếp, monotonic elapsed để đo thời lượng; turn trước/sau khi phù hợp.
- Checkpoint revision/turn lúc resume và revision gốc lúc action bắt đầu. Event phải ghi nguồn quan sát, không trộn sự kiện do người chơi nhập tay với event engine.
- Payload nhỏ, theo loại sự kiện: content ID/version, amount, reason, source/target. Không nhét toàn bộ inventory/state vào mọi event.

### Những sự kiện đáng ghi

| Nhóm | Dữ liệu tối thiểu | Lý do |
|---|---|---|
| session/resume/save/close | checkpoint revision+turn, attempt mới, save succeeded/failed, duration có focus/unpaused | biết đang phân tích nhánh nào và bao lâu |
| damage/heal/status | source kind+content ID, direct/periodic/environment/starvation, target, actual amount, HP trước/sau; apply/remove/cleanse với stack/duration | giải thích Bleed và khả năng hồi; có thể gộp periodic tick theo target/source/turn |
| player death | final source, status/source liên quan, HP trước/sau, mode, checkpoint chưa bị sửa | giữ được death Normal Mode dù save sống bị load lại |
| talent/skill | trigger/cast thành công, ability ID, actual effect/cost, cooldown; refusal reason cho hành động skill có chủ đích | phân biệt biết skill với sử dụng; đo heal/cap và synergy |
| loot/item/equip/progression | source và receipt ID, delta quantity; item consumed, actual restored; slot trước/sau; XP source và level-up | nguồn progression, tài nguyên và giá trị upgrade |
| location | discovery, interaction, event/version, branch ID thực chạy, receipt và effect thực sau cap | không phải tái tính chance để đo nội dung |

`creature_defeated` cần instance ID, definition/version, source kết liễu và reward/XP. Chưa có battle lifecycle chính thức thì không dựng battle count từ mỗi kill. Nếu thêm `combat_started/ended` sau, phải định nghĩa rõ cách nhóm giao tranh, rút lui và passive hunting trước khi tính win rate.

Movement/exploration chỉ cần **aggregate tại save/close**: số valid moves, tổng turn theo action category, số ô/chunk mới, lượt ở mỗi need band. Nếu muốn ước lượng khoảng trống POI, dùng delta aggregate khi discovery thay vì route từng bước. Focus/pause events cộng duration; không gọi toàn bộ thời gian app mở là active play. Idle vẫn cần định nghĩa riêng, không suy ra tâm lý người chơi.

### Rollback và độ tin cậy

1. Mỗi lần resume tạo `attempt_id` mới tham chiếu đúng checkpoint revision/turn. Không xóa journal của attempt chết hoặc bị bỏ.
2. Action/effect thành công trong RAM vẫn có thể **chưa được save**. Gắn base checkpoint cho chúng; chỉ event `save_committed` sau khi transaction thành công mới liên kết chúng với checkpoint mới. Ghi save failed riêng; không tuyên bố event đã bền vững trong save.
3. Với death Normal Mode, append/flush event death riêng trước khi chuyển màn hình; tuyệt đối không lưu `dead` vào Run chỉ để phục vụ telemetry. Nếu sau đó load lại, ghi resume từ checkpoint cũ để tách nhánh.
4. SQLite và JSONL không có transaction chung. Sau crash có thể thiếu event hoặc có event chưa nằm trong save. Mark phiên không đóng/checkpoint chưa khớp là **incomplete**, không tự sửa save hoặc bịa phần thiếu.
5. Event ID/action ID hỗ trợ loại duplicate khi flush retry; một `loot_awarded` chỉ quan sát kết quả, không phát lại award khi đọc journal. Ghi file lỗi/đĩa đầy không được đổi gameplay outcome; báo khoảng trống bằng cảnh báo/flag thay vì âm thầm coi là log đủ.
6. Buffer có giới hạn; flush sau death/save/close và theo số lượng/thời gian hợp lý, rotate theo dung lượng. Không fsync mỗi movement hoặc log mỗi frame. Duration, cỡ buffer và cỡ file cần benchmark trước khi chốt.

Đây là nhật ký hỗ trợ phân tích, **không phải event sourcing, crash-recovery save hoặc cơ chế replay gameplay**.

### Kiểm chứng trước khi dùng journal để chỉnh balance

- Một action chỉ sinh một nhóm outcome, không nhân đôi loot khi retry đọc/ghi.
- Normal death → journal còn death → resume checkpoint cũ, Run vẫn giữ đúng save sống.
- Save failed, abrupt exit, session không đóng: kết quả được đánh dấu thiếu/chưa commit đúng.
- Direct hit, Bleed tick, environment và starvation có source khác nhau; actual heal không tính overheal.
- Có thể tách thống kê **toàn bộ attempt quan sát** và **nhánh save đang giữ**; không cộng cả hai lẫn nhau.
- Không network/secrets/raw seeds; game vẫn chơi khi journal không ghi được; giới hạn bộ nhớ/dung lượng rõ.

## 5. Dữ liệu cần từ phiên kế tiếp

**Trước khi journal được triển khai:** xuất snapshot trước/sau phiên trên bản sao, giữ cục bộ; người chơi ghi ngắn thời lượng ước lượng, tình huống khó hiểu, death/reload và skill/talent thấy kích hoạt. Đánh dấu đây là self-report, không biến chênh lệch inventory thành số item đã dùng hoặc chênh lệch turn thành mọi lượt thực chơi.

**Sau khi có journal đã kiểm thử:** ưu tiên source damage/death, talent actual heal/cooldown, skill usage/refusal, nhu cầu before/after và consumption, XP/level-up, loot/equip, place branch, session/attempt/checkpoint. Hỏi thêm vài phản hồi ngắn về độ rõ status, mục tiêu khám phá và quyết định giữ đồ; telemetry không đo được “vui” chỉ bằng số lượt.

Không cần full movement trace. Không yêu cầu người chơi reset Run01 để bắt đầu ghi. Tiếp tục mẫu mid-game này; dùng một Run02 riêng để đo early-game khi có mục tiêu so sánh rõ.
