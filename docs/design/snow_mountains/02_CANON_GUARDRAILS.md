# Canon Guardrails — đối chiếu audit 2026-11-06

Đây là bản **tóm lược trung thực từ audit** do người dùng cung cấp, không dùng ảnh tạo AI làm nguồn lore. Đọc `SNOW_MOUNTAINS_CANON_AUDIT.md` nếu cần chi tiết định nghĩa ID và source code.

## A. Đã triển khai — CANON_IMPLEMENTED

### Địa lý và weather
- Chỉ có một **cluster bảy area** với tuyến vòng quanh vách băng trung tâm: Leefoot Basin (danger 0) ↔ Pitchpine Reach/Mirror Trough (danger 1) ↔ Broken Relay/Windcut Stair (danger 2) ↔ White Choir/Crown Shelf (danger 2–3). Không mô tả toàn Snow Mountains bằng 7 area này.
- Tuyến thấp: Basin → Pitchpine → Broken Relay → Windcut và Basin → Mirror Trough (hai bờ) → Windcut. White Choir/Crown Shelf là nhánh cao tùy chọn.
- Có một gate đèo tương thích. Spawn Run hiện chỉ được chọn giữa các điểm trú an toàn tại **Leefoot Basin**, không phải toàn bộ đại vùng.
- Cơ chế blizzard deterministic theo land/clock, có forecast, cover/shelter, nguy cơ exposure. Hiện chưa duyệt cảm giác/hình ảnh/balance cuối.
- `manifest.json.binding` rỗng: runtime definitions tồn tại **không có nghĩa đã được publish vào một World**.

### Quest/interaction chính đang có

| Cụm | ID / điểm | Hành vi đã xác nhận | Không được tự nhận |
|---|---|---|---|
| Carrier's Debt | `snow:place/lee_shelter` → `snow:place/relay_locker` → `snow:place/fallen_relay_pine` → locker terminal | Ledger nêu Carrier Ysolde, clasp; Return/Force loại trừ; Keep = không chọn terminal; per-Run | Có hội thoại Ysolde sống; có NPC nhận hàng; Keep là nút lựa chọn |
| Bell restoration | `snow:place/bell_cairn`, `snow:place/summit_bell` | v2 cai rn cho shard chắc chắn; Examine trước, ring sau; mantle/heal/regen; per-Run | Chuông dập bão toàn region; Bell Salvage đã có |
| Crown Beacon | `snow:place/crown_beacon` | Mend (2 bronze), Kindle calm (ember heart), Vigil storm, Feed định kỳ; first fire in years | Beacon tự động thắp từ đầu, hồi sinh toàn thung lũng |
| White Choir | `snow:place/choir_hollow` | Chỉ khám phá trong blizzard; Listen road calls; Offer stormglass lấy Whiteout Lens | Whiteout Lens có tác dụng mở fog/map nếu chưa được định nghĩa; voices chắc chắn là ma |
| Micro-chains | Glass bowl, Singing ice, Cold kiln, Wind loom, Field satchel, Hunters camp | Nhận kỹ năng/knowledge/reward theo prereq | Đã có quest log/dialogue tree tổng quát |
| Choices/cache | strongbox, Ashmaw hollow, prowler den, toll cairn, carrier drift, frozen caches | Exclusive choices hoặc cooldown/use count; heat/force có hậu quả | Dùng text event JSON thay cho kết quả world-rule handler |

### Inhabitants
- **Carriers & bell keepers**: cộng đồng nghề trong quá khứ, có Ysolde, logbook, tín hiệu, pay chest, shelters.
- **Relay cutthroats / relay slingers**: enemy identities trong Broken Relay/Windcut, trại encounter có **hai lần trở lại** cùng stash định kỳ; **không** có tên faction, leader hay học thuyết được code.
- **Cinder acolytes**: enemy tại kiln; không tự coi là một tổ chức tôn giáo có thế lực.
- **Hollow carriers**: hostile/encounters theo khu vực và blizzard; bản chất chưa rõ.
- **Không** có NPC hội thoại, merchant, settlement có công dân, faction sống hay dialogue tree.
- Shelter roof có ở Lee, Broken Relay, Windcut; White Choir có hollow trú bão. Cover giảm exposure; **không** phải miễn nhiễm combat.

### Creature ecology
- Con mồi: rime hare, frost stag.
- Một số loài trung lập/đối kháng tùy tương tác: tuskback charger, glassback crawler, ashmaw fire charger.
- Predator/hostile: scree wolf, pine prowler, relay cutthroat, relay slinger, cinder acolyte, hollow carrier, rime lantern, hoarfrost giant.
- Upper creatures: bellback sentinel, pinned Crown elder `snow:elder_bellback` (96 HP), horn dùng cho Bellhorn Hammer; **không** khẳng định đây là thần thú duy nhất toàn thế giới.
- Một số herd/camp/den trở lại, có giới hạn. Không nói AI predator đã hiện thực sự đi săn rime hare chỉ vì có nhãn ecology.

### Site + item exact identities
- Leefoot: Lee shelter, icebound provisions, field satchel, hare run, snowbloom.
- Pitchpine: fallen relay pine, frozen medicine, hunters camp, prowler den, warm spring.
- Mirror: glass bowl, fishing hole, sunken sledge.
- Broken Relay: relay locker, relay strongbox, bandit stash.
- Windcut: old kiln, ashmaw nest, rime ledge.
- White Choir: bell cairn, wind loom, singing ice, choir hollow.
- Crown Shelf: summit bell, carrier drift, toll/rune cairn, crown beacon.
- Đồ vật story: resin, bark ration, bronze scrap, relay clasp, bell shard, rime mantle, ivory tusk, stormglass, frost linen, ember heart, ancient marrow, trough char, elder horn, Whiteout Lens, beacon-keeper's crown, Bellhorn Hammer.
- Lựa chọn và hệ quả quan trọng là **per-Run**; không tự khai báo world-wide migration hoặc địa lý biến đổi do bell/beacon đã code.

## B. Thiết kế nhưng chưa triển khai — DESIGNED_NOT_IMPLEMENTED

- **Bell Salvage ending:** phương án thay thế restoration, cần spawn sentinel bằng transactional event→encounter/rollback capability, chưa có button, reward, terminal state.
- **Sealed cleft/cave expansion:** chỉ được nhắc gợi mở, không có hành động travel/hang riêng, không thể vẽ cửa hang như cửa vào tương tác.
- Nội dung Snow Mountains bên ngoài 7 area: **chưa có** trong code; địa lý macro phải được thiết kế mới.
- Chưa được phê duyệt human playtest cuối, art production, readability và publication/binding.
- Dialogue/journal quest đầy đủ, cutscene, bell audio, state-specific landmark visuals chưa là canon bắt buộc.

## C. Bỏ ngỏ — UNKNOWN_OR_UNDECIDED

- Biên giới, địa chính trị, kích thước chính xác và quan hệ Snow Mountains với đại vùng khác.
- Ai dựng relay, thất bại vì sao, cách bao lâu, carriers còn tồn tại nơi khác hay không.
- Tiểu sử Ysolde, bản chất hollow carriers, White Choir voices, stormglass, giants, runes, toll.
- Các cutthroats/cinder acolytes có tổ chức nào và nguồn gốc ra sao.
- Có ai nghe thấy tiếng chuông summit bên ngoài thung lũng hay không.
- Mối quan hệ guardian sentinel và Crown elder, thần thoại cụ thể và mức độ duy nhất.

## D. Mâu thuẫn lịch sử đã được audit khoanh vùng

- Văn bản V1 gọi cụm bảy area là "entire region"; nay chỉ là initial land.
- Bell cairn v1 40% shard, v2 guaranteed; versioned old saves vẫn có thể chạy v1.
- V1 ba creature và không có crafting là lịch sử đã cũ; gói mới đã có roster/crafting.
- Audit Nov 02 có câu không respawn; layout v7 về sau có returning herds/camp.
- Artboards chỉ minh họa: **không phải bằng chứng** cờ đỏ, lính canh, đèn đường hoặc roof architecture trong lore.

## E. Art state cho Broken Relay cần căn theo sự thật

- Cảnh quan: trạm relay cũ đã không còn thực hiện nhiệm vụ truyền tin như trước; camp hostile đã xuất hiện và có thể trở lại. Không đánh đồng trạm bị bỏ hoang bởi carriers với trạm không có dấu sinh vật/người nào.
- **Nên có:** kết cấu gỗ/đá cũ; ký hiệu truyền tin đã mòn hoặc đứt; dấu vết chở hàng; địa hình bị tuyết và gió tàn phá; shelter có khả năng sử dụng; dấu chiếm dụng tạm của cutthroats ở vị trí encounter nếu art phản ánh encounter.
- **Không tự thêm:** cờ mới treo hàng loạt, đèn sáng liên tục, trạm đang có lính thường trú, nhà buôn, người khai thác thường xuyên, khói bếp mặc định của mọi nhà.
- Đèn/lửa chỉ hiển thị nếu có nguồn và trạng thái hợp lý. **Crown beacon hiện tắt trước khi người chơi kindle; nội dung nói lần đầu thắp lại sau nhiều năm.**
