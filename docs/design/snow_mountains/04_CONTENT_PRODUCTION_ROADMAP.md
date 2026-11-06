# Roadmap — ưu tiên content trước khi mở rộng map

## Mục tiêu hiện tại

Thoát khỏi vòng lặp thêm preview art cho Broken Relay mà không biết bản đồ đang kể chuyện gì. Trước khi sản xuất thêm các map ngoài trời mới, dùng canon audit để xây **content density** cho cụm đầu tiên và **region expansion framework** cho Snow Mountains lớn.

## Stage N0 — cố định nguồn sự thật (hoàn thành về mặt tài liệu)

- `SNOW_MOUNTAINS_CANON_AUDIT.md` là inventory những gì đã triển khai / backlog / bỏ ngỏ.
- Director Pack V1 bổ sung đề xuất sáng tác mới. **Chưa tự thay đổi code**.
- Gắn nhãn tài liệu `IMPLEMENTED`, `PROPOSED_STUDIO_V1`, `OPEN`; không cho AI-generated artboard làm authority.

## Stage N1 — tăng chiều sâu cụm 7 area **trước khi map overhaul tiếp**

### Nội dung
- Giữ các chuỗi Carrier's Debt, Bell Restoration, Crown Beacon, White Choir Lens và micro-chains đang chạy, không làm mất choice/once-per-Run.
- Chuẩn hóa lời mô tả môi trường dựa trên trạng thái: nơi trú không phải vùng an toàn combat, Broken Relay có hostile camp thay vì town active.
- Tạo nhóm **clue/discovery supplement** nhỏ ở các landmark đã có, có đầu mối liên thông thay vì reward mới; ưu tiên tận dụng world_event/location interaction; không đụng hệ thống năng lực mới.
- Đặt kế hoạch cho nhật ký ghi nhận khám phá tự nhiên nếu content cần; **chưa xây quest manager lớn**.

### Art
- Tạm khoanh V4 facade/roof matte-white như blocker; việc sửa alpha cần nguồn PNG sạch, không đánh dấu đã duyệt game art.
- Art/landmark phải dựa vào place ID và trạng thái: Broken Relay là trạm cũ có camp hostile; Crown Beacon ban đầu chưa cháy; sealed cleft chưa có cổng tương tác.
- Không tạo cờ đẹp/đèn phố mặc định chỉ vì concept trước có.

### Tiêu chí N1
- Những tương tác hiện có còn hoạt động y nguyên.
- Người chơi có thể lần theo ít nhất hai nhánh manh mối không tuyến tính, không phải đọc quest marker dài.
- Không có mâu thuẫn giữa phần trang trí hiện ra và nội dung active.
- Bản đồ mới chỉ được triển khai khi site/đường đi/roof state đã có design brief đủ rõ.

## Stage N2 — định nghĩa cụm thứ hai rồi mới làm layout

**Hành động studio:** chọn một tiểu vùng ngoài Hushed Crown từ các đề xuất địa lý, viết 1 trang mục đích địa lý và hệ sinh thái, 2–3 tuyến truyện dài/ngắn, 5–8 landmark có quan hệ cụ thể, ranh giới/traversal/return routes, điều kiện spawn (nếu được chọn) và tính ảnh hưởng đến lore cluster trước.

**Ràng buộc:** không tự cố định vùng mới ở phía đông/tây Hushed Crown khi chưa có world-map contract; không tạo tài nguyên/creature/gear mới chỉ để tăng count. Có cửa ngõ/quá trình vượt địa hình hợp lý.

**Agent:** được triển khai khi studio đã chốt location graph, content IDs, data contracts; streaming seamless outdoors mở rộng theo nhu cầu, không ép một 1920×1600 PNG khổng lồ cho toàn region.

## Stage N3 — phát triển các nhóm trải nghiệm khác nhau

- Một cluster sinh thái khác biệt có creature/resources cụ thể; một cluster có lore/faction hoặc khám phá nhân văn nếu thiết kế được xã hội hợp lý; một cluster có cột mốc nguy hiểm/vật lý đặc biệt.
- Tích hợp các arc liên vùng một cách vừa đủ: không làm người chơi phải hoàn thành cả Hushed Crown mới có quyền khám phá nơi mới.
- Trạng thái thời tiết, bảo toàn position khi vào/ra interior và lưu dữ liệu Run có contract rõ.

## Stage N4 — đánh giá độ lớn và độ sâu của đại vùng

- Kiểm tra các vùng có liên tục về địa lý và khác biệt về cách sống/phiêu lưu không.
- Kiểm tra vòng khám phá nhiều hướng, reward đa dạng, rarity và bí mật được bảo vệ.
- Sự phong phú không đến từ việc sao chép 7 area và đổi tên; nếu thiếu lore và môi trường, dừng sản xuất diện tích để bổ sung.

## Việc coding agent làm **ngay** sau gói này

**Chỉ Stage N1/A: Narrative Content Integration Review** — đọc Bible+audit, kiểm tra thực tế code hỗ trợ những clue supplement nào, đề xuất diff cụ thể cho 3–5 discovery interactions; nếu có đủ schema và không đụng core, triển khai một nhóm nhỏ theo prompt 05. Không sửa art/geometry; không bổ sung vùng mới bằng code lúc này. Không chạy full suite.

## Vì sao không vội dựng toàn Snow Mountains

Nếu dựng map trước lore, AI Studio sẽ lại có nhà, đèn, biểu tượng đẹp nhưng không biết ai dùng chúng; ngược lại nếu cứ viết lore bất tận thì game cũng không tiến. Nhịp đúng: **một đoạn content xác định → một đoạn geography + art hợp lý → runtime evidence → phát triển đoạn kế tiếp**; không lặp lại preview chỉ để chứng minh tool chạy.
