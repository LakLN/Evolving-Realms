# Evolving Realms — Snow Mountains | Director Pack V1

**Ngày:** 2026-11-06  
**Loại:** Tài liệu định hướng sáng tác và mở rộng nội dung — chưa phải thay đổi runtime  
**Nguồn:** `SNOW_MOUNTAINS_CANON_AUDIT.md` (audit repo ngày 2026-11-06, người dùng cung cấp)

## Đọc theo thứ tự

1. `01_REGION_BIBLE.md` — bản thiết kế toàn đại vùng và cấu trúc kể chuyện.
2. `02_CANON_GUARDRAILS.md` — những gì đã thực sự có, không được phá.
3. `03_STORY_ARCS_STUDIO_ONLY.md` — hướng tuyến truyện và bí ẩn (có spoiler về **đề xuất**, không phải bí mật đã được code).
4. `04_CONTENT_PRODUCTION_ROADMAP.md` — thứ tự từ nội dung tới bản đồ, mỹ thuật và gameplay.
5. `05_AGENT_PROMPT_CONTENT_FOUNDATION.md` — tác vụ agent tiếp theo (giới hạn, không yêu cầu viết lại thế giới).
6. `REGION_STRUCTURE_PROPOSAL.json` — dữ liệu cấu trúc *đề xuất*, không phải manifest runtime.

## Trạng thái không được nhầm

- **CANON_IMPLEMENTED:** Có bằng chứng cụ thể trong audit; giữ nguyên kết quả/ID/rules, nhưng không đồng nghĩa nội dung đã publish vì `manifest.json.binding` còn trống.
- **DESIGNED_NOT_IMPLEMENTED:** Đã có ý tưởng trong tài liệu trước, chưa có runtime tương ứng.
- **PROPOSED_STUDIO_V1:** Nội dung mới do ChatGPT xây để mở rộng region; là tài liệu đề xuất, **không được trộn thành canon hiện hữu**, không tự cập nhật code/gameplay.
- **OPEN:** Chưa quyết; tuyệt đối không giả vờ có lời giải.

## Quyết định xương sống

**Snow Mountains là đại vùng địa lý lớn trên bản đồ thế giới, tương đương Sa Mạc/Đại Bình Nguyên/Rừng Rậm; bảy area hiện tại chỉ là cụm khám phá thung lũng đầu tiên.**

**The Hushed Crown** chỉ là tên gọi dân gian cho **cụm thung lũng relay hiện hành**, không áp lên toàn Snow Mountains. Người chơi khám phá ngoài trời liền mạch; vào nhà/hang/dungeon có thể chuyển cảnh. Spawn Run được thiết kế từ các điểm an toàn có kiểm định; hiện runtime chỉ có nhóm Leefoot Basin, về sau mới mở rộng.

## Không nên làm ngay

- Không thay hàng loạt art V4: facade/roof đang có blocker matte trắng, cờ và đèn chưa bám lore. Giữ opt-in, chưa duyệt production.
- Không tăng diện tích world bằng cách lặp bảy map hoặc kéo dài đường đi rỗng.
- Không tự tạo NPC/thị trấn/faction rồi gọi là đã có trong repo.
- Không triển khai quest subsystem lớn chỉ vì bible có tuyến truyện; ưu tiên tương tác và world_event sẵn có khi phù hợp.
- Không xóa/ghi đè save Run cá nhân, không phá layout cũ để dựng nội dung mới.

**Lộ trình:** Canon audit → thiết kế đại vùng + tuyến truyện → tăng chiều sâu cluster đầu tiên → mở rộng từng tiểu vùng hữu cơ → dựng map/art theo đúng lore.
