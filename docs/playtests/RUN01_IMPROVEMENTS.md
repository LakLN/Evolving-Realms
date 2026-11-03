# Run 01 — Đề xuất cải thiện cho Milestone 03

Đọc cùng [Summary](RUN01_SUMMARY.md). Đây là đề xuất thiết kế, **không có code gameplay, migration, reset hay thay đổi balance được triển khai**. Mẫu quan sát là một nhánh save ở turn 3297, không phải cohort người chơi hoặc toàn bộ lịch sử các attempt.

## P0 — Chặn gameplay hoặc mất dữ liệu

**Chưa xác minh được lỗi P0 từ dữ liệu này.** Quick-check SQLite và tham chiếu snapshot hợp lệ; Run alive, có thể phân tích bằng công cụ hiện có. Điều đó không chứng minh mọi luồng gameplay không có lỗi.

Cái chết Bleed turn 68 do người chơi xác nhận là tín hiệu nguy hiểm đầu game, nhưng chết trong Normal Mode rồi load lại là hành vi thiết kế hiện tại. Không tự gọi đây là lỗi damage, talent hoặc mất save; cần timeline nguồn damage, trạng thái và checkpoint để phân biệt. Không đổi damage/DoT hoặc buff Hồi Khí chỉ từ sự kiện này.

## P1 — Top 5, theo thứ tự đáng làm

| Ưu tiên | Cải tiến có phạm vi nhỏ | Bằng chứng / lý do | Cách nghiệm thu trong phiên sau |
|---|---|---|---|
| 1 | **Event Journal cục bộ nhẹ + báo cáo snapshot rõ base/effective** | Không có duration, damage timeline, death cause hoặc tổng skill/talent proc. Hồi Khí được xác nhận nhưng state rỗng; raw max_hp=30 trong telemetry trong khi effective=69. Chưa đủ dữ liệu để chỉnh balance đúng. | Ghi được một death trong Normal Mode mà không thay save sống; phân biệt attempt rollback; nối được save revision với event; exporter ghi rõ base/effective và không sửa DB gốc. Thiết kế ở Gaps, chưa triển khai. |
| 2 | **Giải thích rủi ro status và giới hạn Hồi Khí ngay lúc cần** | Người chơi xác nhận chết do Bleed turn 68. Code DoT lên player không đi qua `talent_guard`; Hồi Khí là recovery sau hit, không hồi sinh sau lethal. Snapshot có gland/cleanse skill nhưng chưa có usage history. | Ở lần trúng Bleed tiếp theo, người chơi đọc được nguồn, stack/duration, tác động lượt tới và các cách xử lý đang có; mô tả talent không gây hiểu nhầm bảo vệ mọi loại damage. Đo damage/heal thực và phản hồi hiểu luật trước khi sửa thông số. |
| 3 | **Hiển thị lợi ích hiện tại và điều kiện synergy của skill** | 11 skill gồm 7 active; chỉ Stoneskin có cooldown khác 0 trên save. Windrunner hiện không có active skill movement để hỗ trợ; Hunter's Mark + Predator's Instinct có synergy nhưng chưa có dữ liệu sử dụng. Đây là tín hiệu khả năng khó thấy lợi ích, không chứng minh người chơi bỏ quên skill. | Hiển thị “chưa có skill phù hợp” cho passive có tag chưa khớp; giải thích một combo đang có và cost/cooldown. Ghi successful cast, refused reason, proc và actual effect. Không ép dùng combo hoặc thêm cây skill mới. |
| 4 | **Kiểm tra khả năng đọc và xử lý hunger/thirst bằng vật phẩm đang có** | Hunger 845 sát danger 850, còn berries23/meat29/water17. Nhu cầu hiện tại có thể là lựa chọn của người chơi, chờ dùng item, hoặc UI chưa rõ; chưa biết thời gian từng ở warning/depleted. | Người chơi hiểu số cao là xấu, thấy vật phẩm nào giải quyết nhu cầu và tác dụng dự kiến đã tính cap; journal ghi before/after, lượt ở từng mức nhu cầu và lượng thực giảm. Không auto-consume, không nerf hunger/drop rate từ snapshot này. |
| 5 | **Giúp đánh giá gear còn giữ và slot trống, giảm nhiễu đồ trùng** | Boots đang trống dù có Hide boots; còn 5 Iron sword, 3 Hide armor và 7 manual đã có skill tương ứng. Chưa biết vì sao giữ/không trang bị hoặc UI gây khó. | Thử luồng compare/equip đã có với người chơi; chỉ bổ sung nhãn slot trống, quality và sách đã học nếu cần. Đo lựa chọn trang bị/số thao tác, hỏi lý do giữ đồ. Không auto-equip, auto-sell, xóa item hay tạo economy mới. |

Các tiêu chí trên là mục tiêu cho lần triển khai và playtest tiếp theo, không phải tính năng đã có. Event Journal là điều kiện đo; chưa có dữ liệu thì không dùng “usage rate thấp” hay “survival quá dễ” làm kết luận.

## Đánh giá gameplay theo từng trục

### Progression

**Quan sát:** level10, XP dư121; theo curve hiện tại cần509 để lên11, còn388. Tổng XP biểu diễn bởi level/XP hiện tại là1336 nếu dùng nguyên curve hiện tại từ level1. Đây là phép tính, không phải tổng XP mọi attempt hoặc XP chỉ từ combat. 44 dead instance và các place có outcome XP cùng tồn tại nên không quy toàn bộ progression cho kill.

**Hàm ý:** nhân vật đã đi qua nhiều mốc unlock, không bị chặn ở đầu game trên nhánh lưu này. Curve 40%/level làm nhu cầu XP level10 lớn hơn level1 (509 so với25); đây là lý do cần đo thời gian/turn giữa các level sau này. Chưa có level-up timestamp hoặc active playtime nên chưa kết luận nhanh/chậm. Các skill học sát nhau ở1859–1862 cho thấy học theo cụm, không cho biết nhặt sách cùng lúc.

### Combat, status và Hồi Khí

**Quan sát:** 44 saved dead instance gồm hostile18, neutral18, passive8; không phải44 trận thắng. HP hiện36/69, DEF8. Người chơi đã báo một lần chết sớm do Bleed.

**Luật xác minh từ code:** Hồi Khí kích hoạt khi hit để lại HP sống dưới35% max, cooldown40, hồi30% max; ở build hiện tại69 max HP tương ứng20 HP trước các modifier/cap khác. Không dùng69 HP để tái dựng turn68 vì chưa biết gear/level khi đó. Recovery không cứu sau lethal; player status tick không gọi cùng hook `on_hit_taken`. Armor DEF không phải lá chắn chung cho mọi periodic damage; resistance/effect modifiers đi đường riêng.

**Hàm ý:** status có ý nghĩa chiến thuật thực tế theo xác nhận người chơi; cần làm rõ khác biệt direct hit/DoT và các counter đã có. Không biết tổng HP talent hồi, lần cứu mạng hoặc tỷ lệ sống tăng. Giữ đây là câu hỏi đo thay vì chẩn đoán talent hỏng hoặc nerf DoT.

### Sinh tồn

**Quan sát:** hunger845, thirst319, starvation accumulator0; có thức ăn, nước,40 herb,2 gland và Verdant Pulse. Nhu cầu vượt warning có thể ngăn recovery thông thường dù còn HP.

**Hàm ý:** ngay snapshot này có công cụ xử lý, chưa thấy bằng chứng thiếu nguồn sinh tồn. Một số đồ dự trữ nhiều không chứng minh luôn dư đồ; 3297 lượt giữ lại cũng không cho biết đã uống bao nhiêu nước, từng thiếu đói bao lâu, hoặc chết ở các attempt bị bỏ. Ưu tiên hiểu hành vi dùng item và lượng hồi thực sau cap.

### Khám phá

**Quan sát:** 26.576 ô nhìn thấy/77 chunk; có cả ba land biome và ocean. Năm nơi có discovery/resolution record, trong đó bốn loạiAI. World có152 region pin revision2; chunk được nạp không đồng nghĩa đã được người chơi nhìn thấy.

**Hàm ý:** geography và pack đều đã tiếp cận được. Chưa biết thời gian đi giữa điểm thú vị, số lần quay lại, bao nhiêu place bị bỏ lỡ trong tầm nhìn hoặc mức hài lòng. Không kết luận place quá thưa chỉ từ5 record; so sánh số place với cả diện tích chunk nạp cũng sai mẫu số.

### Gear, loot, skill

**Quan sát:** hai gear Hiếm Có đang mặc, hai Phế Phẩm đang mặc, slotboots trống; có14 gear trong inventory. 11 skill nhưng thiếu usage timeline. Có49 stone cho Phi Thạch và EN đang đầy; không suy ra EN chưa từng cạn.

**Hàm ý:** loot có biến thiên và đủ để phát sinh lựa chọn, nhưng chưa đo được thời gian tới upgrade, số món bị thay hoặc cái giá dùng skill. Chưa có bằng chứng cần tăng loot Hiếm Có, bỏ quality thấp hoặc tăng số slot. Một nguồn rủi ro UX cụ thể là passive Windrunner chưa có active skill phù hợp trong bộ skill hiện tại.

### Nội dung AI và khả năng chơi lâu dài

**Quan sát:** đủ6 loàiAI có death record,5/6 skillAI đã học,4/6 placeAI đã giải quyết; có AI gear và trophies. Đây là curated pack offline, không phải live content generation. Talent đang dùng là core C, không phải một trong7 talentAI.

**Hàm ý:** nền tảng đưa content vào gameplay đã làm được việc; chưa có dữ liệu để xếp độ độc đáo, tỷ lệ gặp lặp hoặc chất lượng viết. Level không có hard cap, nhưng không có respawn population, crafting/economy hay arc dài được chứng minh trong Run này. Vùng chưa xác lập cho phép content revision mới; không có nghĩa tự có nội dung vô hạn hoặc tiến hóa các vùng cũ.

## P2 — Chỉ làm khi xác minh nhu cầu

1. **Mục tiêu khám phá nhỏ bằng nội dung đã có:** kiểm tra người chơi có hiểu cue search X và điều kiện hidden place hay không; camp/grotto chưa có discovery record. Ưu tiên làm rõ cue hiện có nếu người chơi thực sự bỏ lỡ, không lập tức thêm hàng loạt landmark/quest.
2. **Phân biệt biến thể AI khi quan sát:** pack reuse sprite nền và Mire lurker còn token theo tài liệu art/content. Nếu playtest xác nhận khó nhận ra mối nguy, bổ sung nhận diện loài/status; không dùng snapshot để khẳng định hình ảnh đang gây nhầm.

Chưa ưu tiên thêm combat system, skill tree, crafting, factions, multiplayer hoặc live AI chỉ để kéo dài thời gian chơi. Những hệ thống đó cần một vấn đề được đo và một phạm vi được phê duyệt riêng.

## Quyết định Run 01 hay Run 02

**Tiếp tục Run 01 trước**, vì có build mid-game, content chưa có record tiếp cận và chưa có lý do reset. Phiên tiếp theo nên quan sát một combo đang có, một tình huống status và một quyết định food/gear; tránh ép nguy hiểm để tái hiện cái chết khi chưa có journal.

**Tạo Run 02 sau**, khi muốn đo onboarding, talent khác hoặc so sánh early-game với telemetry mới. Có thể tái sử dụng World nhưng region đã pin vẫn giữ revision, không dùng reset Run để kỳ vọng nâng lại World. Giữ Run01 để so sánh; task này không tạo hay reset Run nào.
