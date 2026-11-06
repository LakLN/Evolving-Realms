# Prompt cho coding agent — Snow Mountains N1, nội dung trước khi thêm map

Project: Evolving Realms (working directory hiện tại). Director Pack nằm tại `docs/design/snow_mountains/` sau khi giải nén; tài liệu audit `SNOW_MOUNTAINS_CANON_AUDIT.md` cũng ở đó hoặc nơi agent đã lưu.

## Goal

Thực hiện **Narrative Foundation N1** trên cluster Hushed Crown hiện hữu. Snow Mountains là một **major world region** rộng lớn; bảy area chỉ là initial local cluster. Không tiếp tục xây map/art mới trong nhiệm vụ này.

### 1. Đọc tài liệu và xác định thẩm quyền

- Đọc `00_START_HERE.md`, `01_REGION_BIBLE.md`, `02_CANON_GUARDRAILS.md`, `03_STORY_ARCS_STUDIO_ONLY.md`, `04_CONTENT_PRODUCTION_ROADMAP.md`.
- So dữ liệu thật trong `content/land_packages/snow_mountain/` và `content/land_layouts/` với audit trước khi chỉnh.
- Nhãn `PROPOSED_STUDIO_V1` là **nội dung sáng tác chưa triển khai**, không được tự đổi nhãn thành `CANON_IMPLEMENTED`.
- Art concept boards KHÔNG phải bằng chứng cờ, đèn đường, người cư trú hay trạng thái beacon.

### 2. Sản xuất một **narrative pass có giá trị dùng được**

Ưu tiên các location interactions đã tồn tại, không sửa reward hay luật game. Cụ thể:

- Chỉnh lời mô tả/tương tác nơi phù hợp để người chơi hiểu Broken Relay là trạm relay cũ **có hostile encampment hiện hành**, không phải thị trấn đang hoạt động; shelter chống weather chứ không khiến combat an toàn.
- Giữ Carrier Ysolde, relay clasp, bell cairn, summit bell, beacon, White Choir calls như nguồn hiện tại. Thêm tối đa **3–5 manh mối môi trường phụ** nếu và chỉ nếu schema/handlers hỗ trợ additively, không đòi quest subsystem; liên kết các hiện tượng **mà không khẳng định** nguyên nhân Hollow Carriers/giọng nói băng.
- Tôn trọng các nhánh terminal (locker Return/Force, Bell Restoration v2, beacon staged); không viết mới Bell Salvage hoặc hang sealed cleft như tính năng playable.
- Nếu không thể bổ sung manh mối riêng một cách an toàn, hãy cải thiện text ở những interaction hiện hữu thay vì tạo cơ chế mới.
- Mọi content mới cần ID rõ, discoverability hợp lý, không phá trigger và không spoil toàn bộ lời giải.

### 3. Chuẩn bị bản art-state handoff N1 (documentation chỉ dựa vào event)

Tạo `docs/design/snow_mountains/HUSHED_CROWN_ART_STATES.md` ghi:
- Broken Relay: condition của old relay, hostile camp, loại evidence nào có/không có.
- Crown Beacon: trạng thái unlit / repaired / kindled / vigil theo existing receipts (không vẽ sáng ngay từ đầu).
- Bell, cairn, locker: những state nào event đã ghi, visual variant nào vẫn chỉ là đề xuất.
- Cờ/đèn/khói/NPC phải có nguồn in-world hoặc state trigger; không mặc định active.

### 4. Bảo toàn kỹ thuật

- Không sửa architecture, spatial layout v11, elevation, collision, creature AI, weather balance, skills/stats, Run 01 cá nhân hoặc save migrations.
- Không thay `manifest.json.binding` hay publish World nếu không có yêu cầu riêng.
- Không thực hiện full suite, không tạo thêm batch concept/placeholder sprites.
- Bounded sanity check cho data parse và các event được chỉnh; nếu không thể chạy, báo cụ thể.
- Không chỉnh source FE (project không có FE web riêng, nhưng không mở rộng phạm vi UI).
- Không tạo `docs` review vô hạn: chỉ một file art-state và một summary diff ngắn.

### 5. Bàn giao

- File content thay đổi (nếu có), exact IDs, hành vi cũ được giữ.
- `HUSHED_CROWN_ART_STATES.md`.
- Báo cáo phân biệt `existing / new optional clues / unresolved canon`.
- Nếu Git metadata thiếu: không nói đã commit; báo địa chỉ workspace và cách bảo toàn thay đổi.

Đây là một **content increment nhỏ có kết quả**, không phải chỉ lập thêm kế hoạch. Sau khi hoàn thành thì dừng; không chuyển sang mở rộng bản đồ hoặc sửa alpha V4.
