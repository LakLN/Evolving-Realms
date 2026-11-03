# Run 01 — Tổng kết cuộc phiêu lưu

Phân tích ngày 2026-11-01, source `9a28f64`. Đây là **snapshot của nhánh save còn giữ lại**, không phải lịch sử đầy đủ mọi lần chơi. Báo cáo có spoiler nội dung.

## Một hành trình đã có hình hài

Từ điểm xuất phát trong rừng, nhân vật đã mở rộng vùng nhìn thấy qua rừng, bãi biển và đồng cỏ, đạt level 10 sau 3.297 lượt được lưu. Những dấu mốc còn giữ lại cho thấy người chơi đã tìm giếng thì thầm, nhận một viên Tide pearl, hấp thu linh mạch, rồi tiếp xúc với bàn thờ ánh trăng, vòng rune và vòng nấm. Đây là những sự kiện có turn khám phá/giải quyết trong save, không phải câu chuyện được dựng từ vị trí hiện tại.

Người chơi xác nhận từng chết do Bleed ở turn 68 rồi tiếp tục từ save trong Normal Mode. Save hiện tại không ghi lại cái chết đó. Hành trình sau khi load tiếp đã đủ dài để có 11 kỹ năng, trang bị AI ở hai slot và trạng thái chết của đủ sáu loài trong AI pack. Thiên phú C — Hồi Khí đã được người chơi xác nhận kích hoạt; số lần và hiệu quả thực tế chưa đo được.

Run hiện vẫn tiếp tục được: trạng thái `alive`, HP còn 36/69, EN đầy 38/38, không có status đang lưu. Hunger 845/1000 đang sát ngưỡng danger 850 dù trong túi vẫn có thức ăn. Đây là một điểm đáng kiểm tra về cách người chơi đọc và quản lý nhu cầu, chưa phải bằng chứng hệ thống sinh tồn mất cân bằng.

## 1. Cách đọc bằng chứng

- **[DB]**: trường hoặc receipt trong SQLite snapshot; chỉ xác nhận trạng thái trên nhánh save này.
- **[Người chơi]**: sự kiện do người chơi xác nhận trong yêu cầu, không nâng thành dữ liệu DB.
- **[Suy ra]**: tính từ DB bằng code/rules hiện tại; ghi rõ giả định, không coi là event lịch sử.
- **[Chưa có]**: dữ liệu không được lưu hoặc không đủ chứng minh.

Định danh đã ẩn để commit: World được gọi là **Run 01**, Run được gọi là **R01**. Full World/Run ID, hai seed, tọa độ spawn/hiện tại, đường dẫn DB và fingerprint snapshot nằm trong phụ lục cục bộ không theo dõi bởi Git: `.tools/RUN01_PRIVATE_APPENDIX.md`. Không đưa raw telemetry/save vào repository.

## 2. Snapshot đã xác minh

| Chỉ số | Kết quả | Bằng chứng / giới hạn |
|---|---|---|
| World / Run | Run 01 / R01, Normal Mode | [DB] xác định duy nhất bằng prefix người chơi cung cấp |
| Terrain / spawn policy | generation v1 / selection v2; spawn rừng | [DB] World header và spawn JSON; seed/tọa độ trong phụ lục |
| Vị trí hiện tại | Biome rừng | [Suy ra] terrain v1 tại vị trí được lưu; không dựng gameplay session |
| Save revision | 118 | [DB] không đồng nghĩa 118 lần nhấn Save hoặc 118 phiên |
| Trạng thái / lượt | alive / 3297 | [DB] không bao gồm mọi lượt bị rollback |
| Level / XP | Adventurer 10, XP dư 121 | [DB] XP này chưa phải tổng XP nhận suốt đời |
| Ngưỡng lên level 11 | 509 XP; còn 388 | [Suy ra] rules hiện tại; 121/509 ≈ 23,8% |
| HP / max HP | 36 / **69** | [DB] HP; [Suy ra] effective max HP, không dùng base max_hp=30 làm trần |
| EN | 38 / 38 | [DB] value; [Suy ra] max theo level |
| ATK / DEF | **23 / 8** | [Suy ra] effective stats; base lưu là 5 / 1 |
| Hunger / thirst | 845 / 319 trên thang 1000; số cao là xấu | [DB] hunger ở warning, còn 5 tới danger; thirst dưới warning 600 |
| Recovery / starvation | 0 / 0 | [DB] accumulator hiện tại, không phải tổng số lần đói/khát |
| Status hiện tại | rỗng | [DB] không nói rằng chưa từng bị status |
| Kỹ năng / thiên phú | 11 / 1 | [DB] một thiên phú core, C — Hồi Khí |
| Inventory | 33 content ID, 519 đơn vị cộng gộp | [DB] cộng cả coin, sách, nguyên liệu và item cá thể; không phải trọng lượng/slot |
| Fog / region | 26.576 ô, 77 chunk có ít nhất một ô khám phá | [DB + giải mã bitmask] không phải 77 chunk được khám phá hết |
| Region Ledger của World | 152 chunk, đều pin revision 2; thêm 1 baseline marker | [DB] phạm vi World, bao gồm chunk nạp nhưng chưa nhìn thấy |
| Sinh vật chết còn lưu | 44 instance khác nhau | [DB] không phải số trận thắng hoặc kill count mọi lần thử |
| Địa điểm | 5 discovered, 5 resolved interaction record | [DB] không đồng nghĩa hoàn tất mọi lựa chọn ở mỗi nơi |

Effective stats được tính bằng chính `CharacterStats.effective`, `TalentRuntime.modifiers`, quality rules và định nghĩa được pin trong snapshot; không gọi `Session.resume` hay `GameStore.open` trên DB cá nhân. Status đang rỗng nên không có buff tạm thời phải cộng thêm.

| Effective stat | Base | Tăng từ level | Gear (kể cả modifier %) | Passive/talent/skill | Tổng |
|---|---:|---:|---:|---:|---:|
| Max HP | 30 | 27 | 7 | 5 từ Luyện Thể | 69 |
| ATK | 5 | 9 | 9 | 0 | 23 |
| DEF | 1 | 4 | 3 | 0 | 8 |

Gear ATK đã bao gồm modifier +10% của Fang charm và làm tròn integer. Hồi Khí không tăng max HP thụ động.

## 3. Thiên phú, kỹ năng và dấu mốc còn giữ lại

**Hồi Khí [DB]:** rank C, thức tỉnh turn 0, record `state={}`. **[Người chơi]:** đã thấy kích hoạt. Không có cơ sở gọi số lần kích hoạt là 0 hoặc tính tổng HP được cứu. Một phần trạng thái có thể đã mất khi rollback, nhưng đó chỉ là giả thuyết, không chẩn đoán lỗi persistence.

| Kỹ năng | Loại | Turn học [DB] | Điều chứng minh được |
|---|---|---:|---|
| Luyện Thể | passive, core | 845 | +5 max HP hiện tại |
| Stoneskin | active, AI | 1266 | cooldown_until=1452; code chỉ ghi mốc này sau dùng thành công, chứng cứ đã dùng trên nhánh lưu, không có tổng số lần |
| Tiên Phát Chế Nhân | triggered, core | 1377 | counter `first_blood.used=25` trên nhánh lưu; không phải 25 trận |
| Hunter's Mark | active, AI | 1784 | đã học; không có usage journal |
| Windrunner | passive, AI | 1859 | đã học; chỉ tác động active skill tag movement, hiện chưa có active skill đó trong bộ đã học |
| Trọng Kích | active, core | 1860 | đã học; không có usage journal |
| Huyết Tế | active, core | 1861 | đã học; không có usage journal |
| Predator's Instinct | passive, AI | 1862 | +35% damage khi target có Marked theo definition; không đo được số lần hưởng lợi |
| Verdant Pulse | active, AI | 2005 | có heal/cleanse; đã học không chứng minh đã dùng |
| Phi Thạch | active, core | 3140 | đã học, có 49 stone hiện tại |
| Thiết Bích | active, core | 3141 | đã học; không có usage journal |

Bảy active, ba passive, một triggered. Ngoài Stoneskin, các active còn lại lưu cooldown_until=0; điều này không phải bằng chứng chưa từng dùng trong mọi lần chơi. Không suy ra turn nhặt sách từ turn học. Không có skill bị quên trong save để truy ngược lịch sử.

## 4. Trang bị và inventory hiện tại

| Slot | Đang trang bị [DB] | Phẩm chất |
|---|---|---|
| Weapon | Iron sword (core) | Hiếm Có |
| Armor | Mossback mantle (AI) | Hiếm Có |
| Helmet | Tideshell helm (AI) | Phế Phẩm |
| Accessory | Fang charm (core) | Phế Phẩm |
| Boots | trống | trong túi có Hide boots Phổ Thông, chưa suy đoán lý do không trang bị |

Định nghĩa giáp AI có wood resistance 35%; mũ AI có water 30% và ice 20%. Đây là thuộc tính gear hiện tại, không phải lượng damage đã tránh. Tổng gear đang giữ: 18 cá thể tính cả bốn món đang mặc — 3 Phế Phẩm, 9 Phổ Thông, 4 Ưu Tú, 2 Hiếm Có. Bốn keepsake không có quality riêng và không tính vào 18 gear.

| Inventory (excluding equipped gear) | Quantity | Quality if recorded |
|---|---:|---|
| Antler sling (`ai:run01/antler_sling`) | 1 | Phổ Thông x1 |
| Manual: Hunter's Mark (`ai:run01/book/hunters_mark`) | 2 | - |
| Manual: Stoneskin (`ai:run01/book/stoneskin`) | 1 | - |
| Scroll: Verdant Pulse (`ai:run01/book/verdant_pulse`) | 1 | - |
| Manual: Windrunner (`ai:run01/book/windrunner`) | 1 | - |
| Dusk fang (`ai:run01/dusk_fang`) | 9 | - |
| Duskfang blade (`ai:run01/duskfang_blade`) | 1 | Ưu Tú x1 |
| Glimmer antler shard (`ai:run01/glimmer_antler`) | 1 | - |
| Thornhare foot (`ai:run01/hare_foot`) | 1 | - |
| Lurker gland (`ai:run01/lurker_gland`) | 2 | - |
| Mossback hide (`ai:run01/mossback_hide`) | 4 | - |
| Mossback mantle (`ai:run01/mossback_mantle`) | 1 | Phổ Thông x1 |
| Tide pearl (`ai:run01/tide_pearl`) | 2 | - |
| Wild berries (`core:berries`) | 23 | - |
| Manual: Luyện Thể (`core:book/body_tempering`) | 1 | - |
| Manual: Tiên Phát Chế Nhân (`core:book/opening_strike`) | 1 | - |
| Old coin (`core:coin`) | 156 | - |
| Crab claw (`core:crab_claw`) | 16 | - |
| Beast fang (`core:fang`) | 14 | - |
| Plant fiber (`core:fiber`) | 31 | - |
| Fresh water (`core:fresh_water`) | 17 | - |
| Wild herb (`core:herb`) | 40 | - |
| Rough hide (`core:hide`) | 11 | - |
| Hide armor (`core:hide_armor`) | 3 | Ưu Tú x1, Phổ Thông x1, Phế Phẩm x1 |
| Hide boots (`core:hide_boots`) | 1 | Phổ Thông x1 |
| Iron sword (`core:iron_sword`) | 5 | Phổ Thông x3, Ưu Tú x2 |
| Traveler's keepsake (`core:keepsake`) | 4 | ungraded x4 |
| Raw meat (`core:raw_meat`) | 29 | - |
| Seashell (`core:shell`) | 11 | - |
| Shell helm (`core:shell_helm`) | 1 | Phổ Thông x1 |
| Small stone (`core:stone`) | 49 | - |
| Wood (`core:wood`) | 78 | - |
| Wooden club (`core:wooden_club`) | 1 | Phổ Thông x1 |

Đây là lượng đang sở hữu, không phải tổng loot từng nhận. Không có quality trên stackable không được tự đổi thành Phổ Thông. Metadata nguồn trên gear chứng minh provenance của món còn giữ, không cung cấp toàn bộ chuỗi nhận/đổi/trang bị.

## 5. Khám phá, sinh vật và địa điểm

Fog đã lưu gồm 10.289 ô forest, 7.464 beach, 6.671 meadow, 2.152 ocean [Suy ra từ seed + terrain v1]. Đây là **ô từng nhìn thấy**, gồm nước/vật cản, không phải bước chân hoặc số lần sang biome. Chưa có route hay tổng quãng đường.

44 instance chết được nối về definition trong đúng World, HP=0 và dead=true. Tất cả 11 loài bên dưới có ít nhất một instance chết. 22 core + 22 AI; theo disposition của definition: 18 hostile, 18 neutral, 8 passive. Không biết số lần người chơi chủ động gây chiến hoặc nguồn kết liễu từng con.

| Loài | Core / AI | Instance chết còn lưu |
|---|---|---:|
| Grey wolf | core | 7 |
| Shore crab | core | 8 |
| Red deer | core | 3 |
| Meadow rabbit | core | 2 |
| Wild boar | core | 2 |
| Mossback boar | AI | 4 |
| Tidecaller crab | AI | 4 |
| Dusk wolf | AI | 9 |
| Glimmer stag | AI | 2 |
| Mire lurker | AI | 2 |
| Thornhare | AI | 1 |

Có 106 creature mutation, trong đó 62 chưa chết. Không gọi đây là 106 cuộc chạm trán: creature có thể chỉ được lưu vì đã di chuyển/biến đổi, chưa chắc người chơi đã nhìn thấy. Các object mutation ghi nhận 112 nguồn thu thập/pickup và 16 weathered chest đã mở/consumed; đây là instance-state trên nhánh lưu, không có timestamp hay số lần tương tác thất bại.

| Địa điểm | Nguồn | Khám phá → giải quyết [DB] | Receipt còn lưu |
|---|---|---|---|
| Whispering well | AI | 173 → wish 326 | Tide pearl ×1 |
| Spirit vein | core | 653 → absorb 659 | không có item receipt; không đồng nghĩa không có hiệu ứng |
| Moonlit altar | AI | 1837 → pray 1847 | không có item receipt |
| Rune circle | AI | 1920 → attune 1927 | không có item receipt |
| Spore ring | AI | 2447 → enter 2451 | không có item receipt; chưa có bản ghi branch/outcome |

Năm tương tác đã có record giải quyết. Một số nơi dùng lựa chọn exclusive; không coi các lựa chọn bị khóa là nhiệm vụ còn thiếu. `received=[]` chỉ nói không nhận item qua receipt đó: không chứng minh có/không heal, poison, ward hoặc lượng XP thực nhận. Có thể tái tính một số nhánh deterministic từ key/definition hiện tại, nhưng báo cáo này không thay phép tái tính bằng lịch sử đã ghi.

## 6. Nội dung AI thực sự đi vào Run

World có 73 definition `ai:run01/...` của pack The Hollow Wilds: 18 item, 11 loot extension, 6 creature, 6 encounter, 6 skill, 2 status, 7 talent, 6 location, 9 world event, 2 item use [DB, đối chiếu manifest/source]. **Registered ≠ encountered ≠ used.**

- Có chứng cứ chết của **6/6 loài AI**; có trophies AI và nguồn gear từ encounter còn giữ.
- **5/6 kỹ năng AI đã học**; Tidal Lash không nằm trong record học hiện tại. Stoneskin có dấu vết cooldown sau sử dụng; các skill còn lại không có lịch sử cast.
- **4/6 loại location AI có record khám phá/giải quyết**. Hunters' camp và Pearl grotto không có record discovery trong save; không kết luận chúng chưa từng được nhìn thoáng qua.
- Hai món gear AI đang mặc; trong túi còn Antler sling, Duskfang blade và một Mossback mantle khác.
- Hai Lurker gland và hai Tide pearl đang có, definition cho phép cleanse/heal hoặc ward/quench; chưa có chứng cứ lịch sử dùng item.
- Không có talent AI trong record thức tỉnh: đang dùng talent core C. Điều này không chứng minh pack talent bị lỗi.

Pack là nội dung được soạn sẵn, cài offline qua registry; Run này không chứng minh AI sinh content trực tiếp lúc chơi. Cùng handler/sprite nền có thể làm biến thể trông quen nhau, nhưng chưa có phản hồi người chơi hoặc chỉ số để kết luận nhàm chán.

## 7. Những gì đã đạt và chưa biết

**Đạt thật:** một Run Normal đã lưu ở level 10, hơn 3.000 lượt, khám phá cả ba land biome, mở rương/thu thập, học 11 skill, dùng gear AI, có death-state của đủ sáu loài AI và giải quyết bốn loại địa điểm AI. Vòng lặp khám phá → loot → học/trang bị → tiếp tục đã có bằng chứng trong save; chưa phải hoàn thành toàn bộ game.

**Chưa biết:** thời gian chơi, toàn bộ lượt bị rollback, số trận/thắng/thua, timeline damage/heal/status, nguyên nhân cái chết từ DB, tổng talent proc, skill adoption, nguồn mọi XP, lượng food/water từng dùng và mức hài lòng. Sự kiện Bleed turn 68 và Hồi Khí kích hoạt thuộc bằng chứng người chơi, không bị xóa khỏi báo cáo chỉ vì save thiếu.

**Khuyến nghị:** tiếp tục Run 01 như mẫu mid-game; chưa có bằng chứng cần reset. Ở phiên tới có thể kiểm tra chủ động bộ skill/cleanse và tìm hai loại place chưa có record. Sau khi có journal được triển khai riêng và có mục tiêu thử onboarding/talent khác, tạo Run 02 trong cùng World để đối chiếu early-game; giữ Run 01. Nếu thử content distribution mới cần đi vào region chưa xác lập hoặc tạo World mới có chủ đích, không reset ledger cũ âm thầm.

Top 5 cải tiến và tiêu chí đo: [RUN01_IMPROVEMENTS.md](RUN01_IMPROVEMENTS.md). Thiết kế journal, độ tin cậy và dữ liệu phiên sau: [RUN01_TELEMETRY_GAPS.md](RUN01_TELEMETRY_GAPS.md).

## 8. Phương pháp và kiểm chứng

Game đã đóng bằng luồng window-close bình thường trước khi lấy snapshot; sau đó không có process game. DB gốc mở Python SQLite URI `mode=ro`, `PRAGMA query_only=ON`; quick_check=ok, schema=2. Backup API chỉ ghi ra bản sao cục bộ. SHA-256 DB gốc được đối chiếu trước/sau phân tích. Không dùng migration, tạo World/Run, gameplay session hoặc pack activation.

Exporter có sẵn `scripts/export-telemetry.ps1` đã chạy **chỉ trên bản sao**, vì adapter GameStore không cam kết kết nối read-only. Cross-check JSON với SQL read-only: turn, level/XP, creature-dead, place records và fog. Stats được tính bằng helper thuần trên JSON/rules, không mở DB. Kiểm tra tham chiếu/quantity/item identity chỉ phản ánh snapshot, không chứng minh không từng mất/nhân đôi loot.

Raw snapshot, manifest, telemetry, helper và phụ lục nằm trong `.tools/` bị Git ignore. Không chạy test tạo fixture World/Run hoặc full regression cho task đọc dữ liệu; kiểm chứng là đối chiếu dữ liệu, tính lại bằng code thuần và kiểm tra diff/tài liệu. Source dùng để giải nghĩa: [World/Run](../WORLD_SYSTEM.md), [telemetry](../RUN01_TELEMETRY.md), [stats](../../src/core/character_stats.gd), [talent](../../src/core/talent_runtime.gd), [skill](../../src/run/skill_actions.gd), [status](../../src/run/status_runtime.gd), [pack](../RUN01_CONTENT_PACK.md).
