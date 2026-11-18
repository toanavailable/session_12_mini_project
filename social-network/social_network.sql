-- =====================================================
-- MINI PROJECT: CƠ SỞ DỮ LIỆU "SOCIAL NETWORK"
-- Hệ quản trị: MySQL 8.0
-- =====================================================

DROP DATABASE IF EXISTS social_network;
CREATE DATABASE social_network CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE social_network;

-- =====================================================
-- 1. TẠO BẢNG (mọi khóa ngoại đều ON DELETE CASCADE)
-- =====================================================

CREATE TABLE users (
    user_id    INT AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(50)  NOT NULL UNIQUE,
    password   VARCHAR(255) NOT NULL,                 -- lưu chuỗi băm, không lưu mật khẩu gốc
    email      VARCHAR(100) NOT NULL UNIQUE,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    post_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT      NOT NULL,
    content    TEXT     NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN  NOT NULL DEFAULT FALSE,       -- mở rộng: xóa mềm
    CONSTRAINT fk_posts_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE likes (
    user_id    INT      NOT NULL,
    post_id    INT      NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id),                   -- mỗi người chỉ thích 1 bài 1 lần
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_likes_post FOREIGN KEY (post_id)
        REFERENCES posts(post_id) ON DELETE CASCADE
);

CREATE TABLE comments (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id    INT      NOT NULL,
    user_id    INT      NOT NULL,
    content    TEXT     NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_post FOREIGN KEY (post_id)
        REFERENCES posts(post_id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE friends (
    user_id    INT         NOT NULL,                  -- người gửi lời mời
    friend_id  INT         NOT NULL,                  -- người nhận lời mời
    status     VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, friend_id),
    CONSTRAINT chk_friends_status CHECK (status IN ('pending', 'accepted')),
    CONSTRAINT chk_friends_not_self CHECK (user_id <> friend_id),
    CONSTRAINT fk_friends_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friends_friend FOREIGN KEY (friend_id)
        REFERENCES users(user_id) ON DELETE CASCADE
);

-- =====================================================
-- 2. CHỈ MỤC
-- =====================================================
CREATE INDEX idx_posts_created_at ON posts (created_at);
CREATE INDEX idx_friends_friend_status ON friends (friend_id, status);   -- tra cứu chiều ngược lại

-- =====================================================
-- 3. DỮ LIỆU GIẢ LẬP (MOCK DATA)
-- =====================================================
INSERT INTO users (user_id, username, password, email, created_at) VALUES
    (1, 'an_nguyen',  SHA2('An@123456',   256), 'an.nguyen@gmail.com',  '2026-01-05 08:00:00'),
    (2, 'binh_tran',  SHA2('Binh@123456', 256), 'binh.tran@gmail.com',  '2026-01-10 09:30:00'),
    (3, 'cuong_le',   SHA2('Cuong@12345', 256), 'cuong.le@gmail.com',   '2026-02-01 14:15:00'),
    (4, 'dung_pham',  SHA2('Dung@123456', 256), 'dung.pham@gmail.com',  '2026-02-20 20:45:00'),
    (5, 'ha_vu',      SHA2('Ha@1234567',  256), 'ha.vu@gmail.com',      '2026-03-03 07:10:00');

INSERT INTO posts (post_id, user_id, content, created_at, is_deleted) VALUES
    (1, 1, 'Chào mọi người, hôm nay trời đẹp quá!',          '2026-03-10 08:00:00', FALSE),
    (2, 2, 'Chia sẻ tài liệu học SQL cho người mới bắt đầu.', '2026-03-11 10:30:00', FALSE),
    (3, 3, 'Cuối tuần này có ai đi cà phê không?',            '2026-03-12 19:00:00', FALSE),
    (4, 1, 'Bài viết thử nghiệm, sẽ xóa sau.',                '2026-03-13 21:00:00', TRUE),   -- đã xóa mềm
    (5, 4, 'Mới tham gia mạng xã hội, xin chào cả nhà.',      '2026-03-14 07:30:00', FALSE);  -- chưa có tương tác

INSERT INTO likes (user_id, post_id) VALUES
    (2, 1), (3, 1), (4, 1),
    (1, 2), (3, 2),
    (1, 3),
    (2, 4);

INSERT INTO comments (post_id, user_id, content) VALUES
    (1, 2, 'Đúng rồi, trời đẹp thật!'),
    (1, 3, 'Đi dạo thôi nào.'),
    (2, 1, 'Cảm ơn bạn đã chia sẻ.'),
    (2, 4, 'Tài liệu rất hữu ích.'),
    (2, 5, 'Mình lưu lại để học dần.'),
    (4, 3, 'Bài này sao lại xóa vậy?');

INSERT INTO friends (user_id, friend_id, status) VALUES
    (1, 2, 'accepted'),
    (3, 1, 'accepted'),     -- người khác gửi lời mời tới user 1
    (1, 4, 'accepted'),
    (1, 5, 'pending'),      -- chưa chấp nhận: không được hiển thị
    (2, 3, 'accepted');

-- =====================================================
-- 4. CHỨC NĂNG 1: view_user_info (hồ sơ người dùng an toàn)
-- =====================================================
CREATE OR REPLACE VIEW view_user_info AS
SELECT user_id, username, email, created_at
FROM users;

-- =====================================================
-- 5. CHỨC NĂNG 2: view_post_statistics (thống kê tương tác)
--    Mở rộng: chỉ thống kê bài viết chưa bị xóa mềm
-- =====================================================
CREATE OR REPLACE VIEW view_post_statistics AS
SELECT p.post_id,
       u.username                    AS author,
       p.content,
       p.created_at,
       COUNT(DISTINCT l.user_id)     AS total_likes,
       COUNT(DISTINCT c.comment_id)  AS total_comments
FROM posts AS p
INNER JOIN users    AS u ON u.user_id = p.user_id
LEFT  JOIN likes    AS l ON l.post_id = p.post_id
LEFT  JOIN comments AS c ON c.post_id = p.post_id
WHERE p.is_deleted = FALSE
GROUP BY p.post_id, u.username, p.content, p.created_at;

-- =====================================================
-- 6. CHỨC NĂNG 3: sp_add_user (đăng ký tài khoản)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_add_user;

DELIMITER //

CREATE PROCEDURE sp_add_user(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email    VARCHAR(100)
)
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Email đã được sử dụng';
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tên đăng nhập đã được sử dụng';
    END IF;

    INSERT INTO users (username, password, email)
    VALUES (p_username, SHA2(p_password, 256), p_email);
END //

DELIMITER ;

-- =====================================================
-- 7. CHỨC NĂNG 4: sp_create_post (đăng bài, trả về ID mới)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_create_post;

DELIMITER //

CREATE PROCEDURE sp_create_post(
    IN  p_user_id     INT,
    IN  p_content     TEXT,
    OUT p_new_post_id INT
)
BEGIN
    SET p_new_post_id = NULL;

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Người dùng không tồn tại';
    END IF;

    IF p_content IS NULL OR TRIM(p_content) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nội dung bài viết không được để trống';
    END IF;

    INSERT INTO posts (user_id, content)
    VALUES (p_user_id, p_content);

    SET p_new_post_id = LAST_INSERT_ID();
END //

DELIMITER ;

-- =====================================================
-- 8. CHỨC NĂNG 5: sp_get_friends (danh sách bạn bè phân trang)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_get_friends;

DELIMITER //

CREATE PROCEDURE sp_get_friends(
    IN p_user_id INT,
    IN p_limit   INT,
    IN p_offset  INT
)
BEGIN
    -- Chuẩn hóa tham số phân trang
    IF p_limit IS NULL OR p_limit <= 0 THEN
        SET p_limit = 10;
    END IF;
    IF p_offset IS NULL OR p_offset < 0 THEN
        SET p_offset = 0;
    END IF;

    -- Quan hệ bạn bè lưu 1 chiều: lấy "người còn lại" trong cặp
    SELECT u.user_id,
           u.username,
           u.email,
           f.created_at AS friends_since
    FROM friends AS f
    INNER JOIN users AS u
            ON u.user_id = CASE
                               WHEN f.user_id = p_user_id THEN f.friend_id
                               ELSE f.user_id
                           END
    WHERE f.status = 'accepted'
      AND (f.user_id = p_user_id OR f.friend_id = p_user_id)
    ORDER BY u.username, u.user_id
    LIMIT p_limit OFFSET p_offset;
END //

DELIMITER ;

-- =====================================================
-- 9. KIỂM THỬ
-- =====================================================

-- T1. Hồ sơ an toàn: không có cột password
SELECT * FROM view_user_info;

-- T2. Thống kê tương tác: bài 5 chưa có tương tác vẫn hiển thị với 0, bài 4 (đã xóa mềm) bị ẩn
SELECT * FROM view_post_statistics ORDER BY total_likes DESC, total_comments DESC;

-- T3. Đăng ký tài khoản mới thành công
CALL sp_add_user('khoa_do', 'Khoa@123456', 'khoa.do@gmail.com');
SELECT * FROM view_user_info WHERE email = 'khoa.do@gmail.com';

-- T4. Đăng bài và nhận lại ID bài viết mới
CALL sp_create_post(2, 'Bài viết mới tạo bằng thủ tục sp_create_post.', @new_post_id);
SELECT @new_post_id AS new_post_id;

-- T5. Danh sách bạn bè của user 1 (3 bạn accepted, bỏ qua lời mời pending)
CALL sp_get_friends(1, 10, 0);     -- trang đầu: binh_tran, cuong_le, dung_pham
CALL sp_get_friends(1, 2, 0);      -- trang 1 (2 bạn / trang): binh_tran, cuong_le
CALL sp_get_friends(1, 2, 2);      -- trang 2: dung_pham

-- T6. Xóa mềm một bài viết, bài đó biến khỏi thống kê nhưng dữ liệu vẫn còn
UPDATE posts SET is_deleted = TRUE WHERE post_id = 3;
SELECT post_id, author, total_likes, total_comments FROM view_post_statistics;
SELECT post_id, is_deleted FROM posts WHERE post_id = 3;

-- T7. Đăng ký trùng email: bị chặn
-- ERROR 1644 (45000): Email đã được sử dụng
CALL sp_add_user('an_nguyen_2', 'Abc@123456', 'an.nguyen@gmail.com');
