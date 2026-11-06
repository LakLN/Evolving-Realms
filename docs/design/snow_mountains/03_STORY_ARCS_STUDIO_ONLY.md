# Story Architecture V1 — STUDIO ONLY / SPOILERS PROPOSED

**Không phải kịch bản công bố cho người chơi.** Phần [IMPLEMENTED] lấy từ audit. Phần [PROPOSED] là hướng sáng tác mới, hoàn toàn có thể thay hoặc bỏ; không trình bày nó như bí mật đã có lời giải trong code.

## A. Hushed Crown: câu chuyện địa phương mang sức nặng, không chiếm hết Snow Mountains

### A1. The Last Road Call — xương sống bí ẩn của cụm đầu tiên [PROPOSED]

**Tiền đề [IMPLEMENTED]:** carriers dùng chuông, road-calls, dấu đá, shelter; Carrier Ysolde để mất clasp, ledger nằm ở Broken Relay; White Choir ice phát lại giọng gọi, danh tính/bản chất chưa rõ; summit bell hỏng; beacon từng tắt nhiều năm.

**Động lực điều tra [PROPOSED]:** người chơi nhận ra các road-calls không chỉ ghi đường đi mà còn chỉ dẫn cách tránh một đoạn đường đèo trong bão. Không hiện marker quest; những người chịu khó nhớ mốc địa lý mới hiểu thứ tự lời gọi. Những manh mối ở các site hiện hữu **không thay sự kiện/reward đã code**, mà mở lời mô tả hoặc discovery supplement mới (cần map data cụ thể khi triển khai).

**Nhánh tìm hiểu:** đọc ghi chép thực địa, so chênh lệch giữa tiếng gọi cũ và đường hiện nay, đi qua tuyến vòng thấp trước khi tự mạo hiểm nhánh cao. Có thể có nhiều diễn giải; đừng gắn chiến thắng combat duy nhất làm lời giải.

**Điểm kết [PROPOSED]:** người chơi có thể hiểu rõ hơn một quyết định sinh tồn trong quá khứ, nhưng **không** tự đổi Bell Restoration thành phép xóa bão, không phủ định việc beacon phục hồi chỉ tác dụng Run-local. Danh tính Ysolde và nguyên nhân kết thúc mạng lưới vẫn có thể để dành cho cluster khác.

**Kết quả mỹ thuật:** relay signs, ký hiệu cổ trên đá, gỗ, dấu sửa chữa và chuông nứt là phần chính; cờ mới và đèn hàng loạt là sai giọng điệu nếu không có event mới.

### A2. Three Kinds of Refuge — chuỗi quyết định về nơi trú [PROPOSED]

Ba nơi trú không giống nhau: mái có thể bị camp hostile chiếm, hốc đá chỉ trú bão nhưng thiếu thức ăn, lều/hut có dấu người quay lại. Dùng shelter đã có để dạy người chơi phân biệt **protected from exposure** với **safe from encounters**.

Nhịp: Leefoot = trú sinh tồn cơ bản → Broken Relay = trú có rủi ro gặp cutthroats → Windcut = trú địa hình nguy hiểm → White Choir = trú tạm trong điều kiện thời tiết hiếm. Không dựng một NPC chỉ để giao nhiệm vụ.

### A3. The Toll that Counts — điều tra văn bản khắc trên Crown Shelf [PROPOSED]

**[IMPLEMENTED]:** frost runes ghi lại giants và travellers đã trả ivory toll; có thao tác trả tusks, nhận mantle và các reward.

**[PROPOSED]:** đọc dấu khắc ở nhiều đoạn đường sẽ cho thấy mỗi loại du khách đi qua với rủi ro khác nhau. Nên cho phép người chơi hiểu về một luật cũ mà không buộc giải toàn bộ nguồn gốc giants ngay. Không dựng ngay đế chế giant, hiệp ước giữa nhiều vương quốc hay boss thần thoại chưa có dữ liệu.

## B. Các đại tuyến có thể trải xuyên nhiều cluster mới

Mỗi tuyến sau là **PROPOSED**. Tạo tối đa một phần nhỏ mỗi đợt, không đưa mọi lời giải vào cluster 01.

### B1. Roads Nobody Keeps — mạng lưới đường đi thay đổi theo lịch sử

**Chủ đề:** Con đường an toàn nhất hôm qua có thể trở thành cạm bẫy hôm nay. Những mốc dẫn đường là ký ức của các cộng đồng qua lại núi, không phải huyền thuật đồng nhất toàn đại vùng.

**Cấu trúc nhiều cluster:** một bản ghi chỉ đường ở Hushed Crown → một lối đèo đã đổi dòng nước ở Needlewall → một đoạn đường trên băng thay đổi theo thời gian ở Bluevault. Người chơi có thể tự ghép tuyến mới bằng địa lý, không yêu cầu nhất thiết biết tên nhân vật lore.

**Lựa chọn:** đi ngắn nguy hiểm hoặc vòng xa nhưng có nơi trú và tài nguyên; quyết định đường an toàn có hậu quả sinh tồn, không chỉ thưởng XP.

### B2. Warmth Beneath Winter — vùng nước ấm và địa nhiệt [PROPOSED]

**Chủ đề:** tuyết không phải quy luật duy nhất; ở thấp có đầm cỏ, suối ấm, mạch nước xung đột với sương giá. Có thể xảy ra những đối lập sinh thái, chứ không phải cứ thấy ember heart thì tất cả thuộc một hội pháp sư.

**Đường khám phá:** warm spring hiện hữu là manh mối địa chất quy mô nhỏ, nhưng **không khẳng định** có mạch địa nhiệt nối thẳng tới kiln hay Ashfrost Verge. Những quan hệ đó phải được lý giải khi làm cụm mới.

**Cơ chế:** nguồn nhiệt có lợi/hại, sương che tầm nhìn, tuyến tài nguyên khác. Ưu tiên gameplay nằm trong engine hiện tại; đừng build climate simulator toàn cầu trước content.

### B3. The White Atlas — đại vùng không thể được hiểu hết bằng một bản đồ [PROPOSED]

**Chủ đề:** dấu đường của người xưa khác với địa hình hiện tại; quá trình người chơi tự ghi chép quan trọng hơn việc đi theo marker.

**Điều tra:** nhiều bản đồ không khớp do băng dịch chuyển, lở đá và ký hiệu của cộng đồng khác nhau; quyết định đi đâu dựa theo khí hậu, mùa, dấu vật và địa hình. Không tiết lộ mọi site ở minimap ngay khi vào region.

**Kết quả chơi:** khám phá tuyến đi mới; một số hang/đường chỉ có thể tiếp cận khi có thông tin hoặc điều kiện môi trường, nhưng không áp dụng ép buộc cho bảy area đã tồn tại.

## C. Các chuỗi trung bình độc lập để region không rỗng [PROPOSED]

1. **The Lost Load:** xe hàng hoặc xe trượt bị mắc kẹt; từ dấu hư hỏng suy ra chuyện đã xảy ra mà không cần NPC kể trực tiếp. Dựa vào style của sunken sledge, nhưng nội dung mới phải có ID riêng.
2. **A Trail without Tracks:** người chơi truy một dấu mùi/cây bị cào/đường hươu để tìm đường qua rừng; sinh vật không phải auto-aggressive.
3. **When Ice Sings:** môi trường phát âm theo thời tiết; kiến thức đã học ở White Choir giúp nhận biết một tín hiệu khác, **không được tuyên bố hai hiện tượng cùng cơ chế khi chưa thiết kế lời giải**.
4. **The Season Camp:** một địa điểm chỉ có dấu hoạt động theo mùa; người chơi có thể gặp camp theo thời điểm, không nhất thiết phải có thành phố cố định.
5. **The Wrong Shelter:** nơi có mái chống bão nhưng từng bị sinh vật chiếm; tự cân nhắc ở hay rút, shelter không bảo đảm an toàn khỏi combat.
6. **The Ridge Circuit:** mở một shortcut vòng qua chỗ cao; thưởng lớn nhất là tuyến đường thuận tiện, không phải nguyên liệu quý.
7. **Thawline Survey:** tìm chuỗi đá mốc quanh vùng tuyết tan, liên hệ nguồn nước và thời tiết; không biến bài toán địa lý thành UI câu đố tách rời.
8. **The Unlit Signal:** phát hiện một công trình có thể khôi phục nguồn sáng, nhưng không mặc định công trình nào cũng có khả năng thắp lại.

**Chú ý:** đây là các thiết kế mới, chưa có NPC, item, skill, event hay reward. AI Studio cần duyệt yêu cầu engine và thiết kế mục tiêu trước khi cho agent code từng chain.

## D. Mức công khai/bí mật

**Công khai cho người chơi:** tồn tại một thung lũng truyền tin cũ; một số đường dẫn lên đỉnh và các dấu hiệu của người từng đi qua; mỗi địa điểm có hiểm họa và cơ hội.

**Không kể trước:** kết quả các lựa chọn locker, trình tự giành Whiteout Lens, phần thưởng của Crown Elder, lời giải giọng nói băng hoặc tương lai Ysolde; các phương án thiết kế mới về nguồn gốc bão, nghĩa của runes, v.v. Không gán lời giải vào canon khi studio còn đang bỏ ngỏ.

**Thiết kế tiết lộ:** manh mối có thể kiểm chứng, các lời giải khác nhau phải được phân biệt bằng dữ liệu; không triển khai "bí ẩn" chỉ dựa vào caption mơ hồ rồi vô trách nhiệm không có đường giải.

## E. Quy tắc không làm nghèo sáng tạo

- NPC và đô thị **có thể xuất hiện trong khu vực mới** nếu lý do kinh tế/địa lý/cốt truyện rõ, nhưng hiện chưa có trong repo; không để Hushed Crown quyết định rằng tất cả Snow Mountains đều hoang vu.
- Có thể có tuyến cốt truyện có stakes lớn nhưng không bắt toàn bộ game vào một “main story”; hệ thống Run độc lập vẫn là nền tảng.
- Không phóng đại gameplay: nếu người chơi khôi phục beacon, không thay đổi vĩnh viễn thời tiết khắp nơi; nếu giết Crown elder, không tuyên bố cả loài bị tuyệt diệt.
- Cảnh quan phải dẫn dắt hành động: từ xa thấy tháp cũ, xuống gần thấy dấu bandit, kiểm tra thấy sổ; điều gì không có runtime thì không vẽ như có sẵn hành vi tương tác.
