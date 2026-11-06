# Snow Mountains — Region Design Bible V1

> **STUDIO DESIGN, CHƯA PHẢI CANON RUNTIME.** Phần nào là sự thật audit, phần nào là đề xuất mới được đánh dấu. Mục tiêu: đại vùng sinh tồn–RPG–phiêu lưu thực sự, không phải 7 màn chơi tuyến tính. Không tiết lộ toàn bộ bí ẩn cho người chơi trước khi khám phá.

## 1. Tuyên ngôn sáng tác

**Snow Mountains là một lãnh thổ khổng lồ gồm nhiều dãy núi, rừng, thung lũng, băng hà, địa tầng và đường vượt núi**, trải dài đủ để các địa điểm khác nhau có lịch sử, khí hậu, nền kinh tế sinh tồn và hiểm họa riêng. Nó là một trong các đại vùng trên world map Evolving Realms; không có yêu cầu tất cả đỉnh núi thuộc một hệ thống chuông hay một phe.

**Trải nghiệm mong muốn:** ngước nhìn một sườn núi xa và biết có con đường thật sự dẫn tới đó; đi nhiều ngày trong game mà cảnh quan, dấu vết sinh vật, con người và hiểm họa có quy luật; phát hiện những đầu mối rời rạc từ lịch sử, sau đó tự nối chúng; chiến đấu và khai thác có ý nghĩa ngoài kiếm XP. Quy mô phải đến từ **hệ sinh thái, bí ẩn, tuyến khám phá và biến đổi**, không phải diện tích trống.

**Bốn trụ cột:**

1. **Địa lý có nhân quả:** nguồn nước, đường đèo, hướng gió, chỗ trú, đường thương lữ, vị trí sinh vật tạo thành không gian có lý do tồn tại.
2. **Khám phá tự do, đầu mối có cấu trúc:** không ép người chơi theo một cốt truyện chính đơn tuyến, nhưng mỗi phát hiện phải có khả năng dẫn tới nhận thức hoặc lựa chọn mới.
3. **Sinh tồn tương tác với lore:** bão tuyết, đốt nhiên liệu, đường trú, thú di cư và dấu chân là một phần thiết kế truyện, không chỉ là chỉ số.
4. **Thế giới có thể thay đổi:** công trình có trạng thái, hoạt động và quan hệ nhân quả; mọi thay đổi lớn tuân quy tắc Run/World đã chọn, không tự biến thành thay đổi vĩnh viễn của toàn world.

## 2. Quy tắc về nguồn và thay đổi

**[IMPLEMENTED]** Cụm đầu tiên là thung lũng từng sử dụng mạng lưới người đưa tin mùa đông, chuông đồng, đống đá chỉ đường, trạm trú và ngọn lửa trên đỉnh. Có tên gọi dân gian **The Hushed Crown**; một vòng tuyến đường bao quanh vách băng trung tâm không thể vượt qua, có một mountain-pass gate tương thích.

**[IMPLEMENTED]** Chuỗi Carrier's Debt, Bell Restoration, Crown Beacon và White Choir Lens, cùng nhiều micro-chain, tồn tại dưới dạng location interactions / world_event / receipts — **chưa có quest subsystem chung**. Các bí ẩn quan trọng như cơ chế White Choir phát lại tiếng gọi và bản chất hollow carriers chưa được giải thích.

**[PROPOSED_STUDIO_V1]** Những địa điểm và tuyến lớn ở các chương sau là gợi ý thiết kế để AI Studio triển khai sau, **không gán chúng vào canonical past một cách âm thầm**. Cần kiểm chứng với các gói runtime trước khi thêm ID, event hay vật phẩm mới.

## 3. Phân cấp quy mô thế giới

```text
WORLD: Evolving Realms
 └── MAJOR REGION: Snow Mountains
      ├── LOCAL LAND/CLUSTER 01: Hushed Crown valley (7 area hiện hữu)
      │    ├── Leefoot Basin, Pitchpine Reach, Mirror Trough
      │    ├── Broken Relay, Windcut Stair
      │    └── White Choir, Crown Shelf
      ├── LOCAL LAND/CLUSTER 02…N: các lãnh thổ thiết kế sau
      ├── shared geographic corridors / natural borders
      └── optional cave, ruin and dungeon interiors
```

*Area* là phân vùng địa lý/streaming ngoài trời, không bắt buộc màn hình chuyển cảnh. *Location/landmark* là địa điểm có hình thái nhận diện và/hoặc nội dung. *Interior* có thể chuyển cảnh độc lập. *Land/cluster* tập hợp nhiều area và vòng chơi địa phương. *Major region* là địa lý lớn, không bị khóa cứng trong một package 7 area.

## 4. Đề xuất các dải địa lý trên toàn Snow Mountains

Dưới đây là **các working name mới, chưa xuất hiện trong repo**, không phải bản đồ cuối. Không khóa vị trí/hướng la bàn hay ranh giới với Desert, Great Plains, Rainforest cho đến khi world map thực sự được thiết kế.

| Dải/cluster đề xuất | Bản sắc sinh thái–thị giác | Chức năng khám phá | Dấu vết người hợp lý |
|---|---|---|---|
| **Hushed Crown Valley** — *cluster hiện hữu* | thung lũng gió, rừng thông, hồ đóng băng, khe nước, cao nguyên chuông | học quy tắc tuyết; manh mối mạng lưới relay cổ; lối qua núi | lịch sử carriers; những kẻ chiếm dụng hostile hiện tại |
| **The Long Thaw** *(đề xuất)* | các thung lũng thấp, nước nóng, thảm cỏ mùa ngắn, tuyết tan theo mùa | sinh tồn chuyển mùa, giao thoa nhiều sinh vật | khả năng có điểm tụ cư/đổi hàng theo mùa, **chưa quyết có thị trấn** |
| **Needlewall Range** *(đề xuất)* | sườn đá dựng, gió xuyên khe, đèo treo, khe nứt sâu | đường leo, shortcut cao độ, hiểm họa địa hình và thời tiết | đường cũ, dấu chân thợ vượt núi, công trình bỏ dở |
| **Bluevault Icefields** *(đề xuất)* | băng hà lớn, hang băng, nước chảy ngầm, bề mặt băng chuyển động | đọc địa tầng, đòi hỏi chuẩn bị/thiết bị, tìm lối dưới băng | dấu khảo sát và đồ vật mắc kẹt, không mặc định dân cư |
| **Ashfrost Verge** *(đề xuất)* | đá tối, hơi ấm địa nhiệt hiếm, tro cũ đọng dưới tuyết | đối lập nóng–lạnh, nguyên liệu và nguy cơ đặc thù | có thể dẫn tới truyền thống lò nung, **chưa đồng nhất với cinder acolytes hiện tại** |
| **Farwhite Plateau** *(đề xuất)* | cao nguyên trống, bão trắng, trời rộng, mốc đá hiếm | bài kiểm tra định hướng, khu săn/di cư của creature cao cấp | có thể có caravan tuyến mùa, không mặc định trạm đèn sáng |

Đây là **các ý tưởng về sự đa dạng địa lý**, không phải danh sách bắt buộc phải xây đủ sáu khu rồi mới được phát hành một Run. Có thể hợp nhất, đổi tên hoặc bỏ bất kỳ dải đề xuất nào khi chuỗi nhiệm vụ và địa lý thế giới phát triển.

## 5. Cụm Hushed Crown — ràng buộc thực tế

**[IMPLEMENTED]** Leefoot Basin là Danger 0, vùng khuất gió, có các vị trí spawn đã kiểm định theo Run seed; có thức ăn/nước gần và đường thoát. Route phía tây tới Pitchpine, phía đông tới Mirror Trough. **Không được tự tuyên bố spawn hiện triển khai ở nhiều cluster khác.**

**[IMPLEMENTED]** Pitchpine Reach (Danger 1, lee) là vòng rừng thông có thú săn, kẻ săn mồi, vết tích người đưa tin; hướng tới Broken Relay. Mirror Trough (Danger 1, open) là bờ hồ và đường ven vách, không phải hồ băng chạm vào là chết; nối tới Windcut.

**[IMPLEMENTED]** Broken Relay (Danger 2, open) là một trạm đã ngừng hoạt động như relay có locker/strongbox/stash và một **hostile camp cutthroat/slinger tái xuất**. Đây không phải thị trấn đang hoạt động. Nó có shelter mái, không đồng nghĩa chỗ nghỉ luôn an toàn trong combat. Bố cục v11 là rebuild lựa chọn tại chỗ, không xác lập tất cả lịch sử.

**[IMPLEMENTED]** Windcut Stair là lối cao độ, nhà trú trên ledge và vùng kiln, dẫn tới mountain-pass gate. White Choir là lòng chảo bão tuyết với các road-calls đóng băng. Crown Shelf là điểm cao hiểm trở của chuông, beacon và dấu trả ivory toll. White Choir và Crown Shelf là nhánh khám phá trên cao, không phải quest gate bắt buộc để rời thung lũng.

**Không thiết kế art khiến relay trông như một thành trì có lính gác, hệ đèn đường đang được duy trì và cờ mới như canon**, trừ khi một event/quest/sự kiện vùng cụ thể tạo ra trạng thái đó.

## 6. Sự hiện diện của con người: logic chứ không đoán mò

**[IMPLEMENTED]** Từng có carriers và bell keepers; Ysolde được ghi trong ledger. Có dấu nghề sinh tồn và thương lữ: đống đá chỉ đường, săn bắt, đánh cá, nguồn lương thực, sledges, caches. **Không có NPC hội thoại, faction sống, thành phố hay xã hội đang tồn tại được code trong Snow pack.**

**[IMPLEMENTED]** Cutthroats/slingers hiện là hostile creature identities, có trại trở lại tại Broken Relay/Windcut; cinder acolytes là encounter ở kiln; hollow carriers xuất hiện theo vùng/thời tiết nhưng bản chất chưa chốt. Không suy từ tên để khẳng định họ thuộc tổ chức tôn giáo, thế lực chính trị, người chết hồi sinh, v.v.

**[PROPOSED_STUDIO_V1]** Khi mở rộng ra đại vùng, phân bố cư trú nên phụ thuộc khả năng tiếp cận nước, gỗ, thú, thương lộ và an toàn tương đối. Ở các thung lũng thấp **có thể** tồn tại chợ mùa và trạm trao đổi; trên đỉnh bão là lều tạm hoặc phế tích. Không tạo một vương quốc tuyết đồng nhất để lấp bản đồ.

## 7. Nhịp phát triển cốt truyện không tuyến tính

- **Giai đoạn làm quen:** tìm nước, nơi trú, dấu đường; tác động thời tiết được học qua thế giới thay vì popup giảng giải. Có thể bắt đầu nhiều điểm khuất gió *sau khi* feature mở rộng spawn được thực hiện.
- **Giai đoạn khám phá khu trú:** phát hiện các tuyến thấp, chọn đường rừng hoặc hồ; ghi nhớ landmark; mỗi tuyến có cơ hội riêng nhưng không bắt buộc chọn "đúng".
- **Giai đoạn tương tác với quá khứ:** locker, ngọn chuông, tiếng gọi, đống đá; đọc câu chuyện không cần giải nghĩa tất cả ngay.
- **Giai đoạn vượt núi:** chuẩn bị, chấp nhận rủi ro bão/sinh vật/cao độ, mở các tuyến địa lý tiếp theo; người chơi có thể rời cụm trước khi hoàn thành mọi bí mật.
- **Giai đoạn trở lại:** áp dụng kiến thức, vật phẩm, kỹ năng hay phát hiện mới để thấy một địa điểm cũ dưới góc nhìn khác; không nhất thiết có quest marker mới.

## 8. Hệ sinh thái và sinh tồn đa tầng

**[IMPLEMENTED]** Rime hare/frost stag là con mồi; tuskback, glassback, ashmaw có trạng thái trung lập/tùy kích động; scree wolf/pine prowler là predator; nhiều loại hostiles và guardian. Các encounter trở lại có giới hạn; **data-driven behavior không có nghĩa predator AI thật sự đi săn con mồi**, không claim tính năng chưa có.

**[PROPOSED_STUDIO_V1]** Đến mỗi tiểu vùng mới, bắt đầu từ chuỗi thức ăn và chuyển mùa, rồi mới tạo creature. Mỗi loài mới cần: lý do sống ở đây, thức ăn/thói quen, dấu vết, thời gian/điều kiện xuất hiện, phản ứng với người chơi và vật thể liên quan. Creature hiếm không chỉ tăng HP, mà nên có dấu hiệu nhận biết, tuyến săn tìm và cơ hội phi chiến đấu.

Weather của Hushed Crown hiện là deterministic theo land/Run clock; những bão khác biệt giữa các dải khác là *đề xuất tương lai*, không thay bằng roll ngẫu nhiên khi reload.

## 9. World state và phong cách event

**[IMPLEMENTED]** Bell restoration, beacon, receipts, lựa chọn locker, thaw/shatter các thùng bị đông, creature return và fog thuộc phạm vi Run. Bell restoration không sửa được bão cả đại vùng; Crown Beacon là nơi trú cá nhân sau các bước, không tái thiết toàn thế giới.

**[PROPOSED_STUDIO_V1]** Content tương lai có thể có trạng thái `untouched / investigated / occupied / repaired / altered` cho site, nhưng chỉ khi world_event và save contract có thể biểu diễn. Tránh biến mọi landmark thành cây nâng cấp 5 cấp. Một số chỉ là nơi đẹp, nơi đáng sợ, hoặc vật chứng không thể khôi phục.

## 10. Art narrative contract — áp dụng trước khi hoàn thiện V4

1. **Nguyên nhân tồn tại:** ở đây từng có người làm gì? Vị trí nhà/cầu/cờ có ý nghĩa gì về địa lý?
2. **Ai dùng hiện tại:** nếu không có chứng cứ người đang bảo trì, mặc định không dựng cửa sổ sáng hàng loạt, cờ thẳng sạch hay phố đèn liên tục.
3. **Thời gian và thời tiết:** tuyết phủ mái và thềm, gió bào mòn cờ, gỗ lạnh tối màu, đá lở theo vách, không phải “ruin decal” random mọi nơi.
4. **Dấu hiện tại riêng biệt:** Broken Relay có camp hostile; có thể có vật tư chuyển động/dấu sinh hoạt ngắn hạn nếu runtime/trạng thái hỗ trợ. Đèn trại khác hẳn hệ thống chiếu sáng được quản lý.
5. **Lighting theo hệ thống:** sáng trời do thời gian/ngày; lửa có nguồn (beacon được thắp theo event, lửa trại nếu có nhóm hiện diện, đèn vật phẩm nếu thực sự được bật).
6. **Mỗi vùng có riêng palette và cấu trúc:** cùng ngôn ngữ Modern Stylized Pixel Fantasy, không copy nguyên nhà/cầu/cây của Broken Relay sang mọi tiểu vùng.
7. **Gameplay đọc được:** đường đi, cao độ, cầu, cửa trú, tương tác không bị đồ họa giấu; không dán layer ảo ở trên để chữa logic collider.

## 11. Điều gì mới khiến Snow Mountains là một region hoàn chỉnh?

Không tính bằng số lượng area cứng hay số quest ép buộc. Đánh giá bằng **chiều rộng và chiều sâu**:
- Người chơi có thể dành nhiều buổi khám phá trong các địa hình có hệ sinh thái và phương thức đi lại khác nhau mà vẫn thấy cùng một thế giới liền mạch.
- Có nhiều tuyến truyện độc lập và vài mối liên hệ dài, không phải 7 phòng chứa 7 quest marker.
- Có động cơ quay lại ít nhất một số nơi vì thông tin/thời tiết/trang bị/trạng thái mới, không do loot respawn vô hạn.
- Khu hiểm nguy có tín hiệu báo trước và lối tiếp cận có chuẩn bị; spawn hợp lệ không mắc kẹt hoặc bị quái cấp cao camp.
- Một số địa điểm có lịch sử nhân quả nhận ra được, một số bí ẩn vẫn giữ khoảng trống có chủ đích.
- Có hiệu quả kỹ thuật: streaming cho outdoors, scene transition cho interiors, trạng thái per-Run và dữ liệu versioned rõ ràng.

## 12. Quyền sáng tạo và nguyên tắc spoiler

AI Studio được phát triển nội dung độc lập và tham khảo từ nhiều loại game, truyện và tài liệu về vùng lạnh, nhưng phải sáng tạo thiết kế nguyên bản, không chép lore tên gọi/hình ảnh đặc trưng từ IP khác. Người chơi là người khám phá: **tóm tắt công khai chỉ nói tiền đề và loại trải nghiệm, không liệt kê chính xác cách giải mọi bí mật, tất cả quái hiếm hay hậu quả các lựa chọn.**
