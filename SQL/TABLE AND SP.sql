USE [CHUNGKHOAN]
GO
/****** Object:  Table [dbo].[LENHDAT]    Script Date: 4/26/2022 5:15:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LENHDAT](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[MACP] [nchar](7) NOT NULL,
	[NGAYDAT] [datetime] NOT NULL,
	[LOAIGD] [nchar](1) NOT NULL,
	[LOAILENH] [nchar](10) NOT NULL,
	[SOLUONG] [int] NOT NULL,
	[GIADAT] [float] NOT NULL,
	[TRANGTHAILENH] [nvarchar](30) NOT NULL,
 CONSTRAINT [PK_LENHDAT] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[LENHKHOP]    Script Date: 4/26/2022 5:15:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LENHKHOP](
	[IDKHOP] [int] IDENTITY(1,1) NOT NULL,
	[NGAYKHOP] [datetime] NOT NULL,
	[SOLUONGKHOP] [int] NOT NULL,
	[GIAKHOP] [float] NOT NULL,
	[IDLENHDAT] [int] NOT NULL,
 CONSTRAINT [PK_LENHKHOP] PRIMARY KEY CLUSTERED 
(
	[IDKHOP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LENHKHOP]  WITH CHECK ADD  CONSTRAINT [FK_LENHKHOP_LENHDAT] FOREIGN KEY([IDLENHDAT])
REFERENCES [dbo].[LENHDAT] ([ID])
ON UPDATE CASCADE
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[LENHKHOP] CHECK CONSTRAINT [FK_LENHKHOP_LENHDAT]
GO
/****** Object:  StoredProcedure [dbo].[CURSORLoaiGD]    Script Date: 4/26/2022 5:15:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CURSORLoaiGD]
@OutCrsr CURSOR VARYING OUTPUT,
@macp NVARCHAR(10), @Ngay NVARCHAR(10), @LoaiGD CHAR
AS
SET DATEFORMAT DMY
IF (@LoaiGD = 'M')
BEGIN
	SET @OutCrsr = CURSOR KEYSET FOR
	SELECT ID,NGAYDAT,SOLUONG,GIADAT FROM dbo.LENHDAT
	WHERE MACP = @macp
	AND DAY(NGAYDAT) = DAY(@Ngay) AND MONTH(NGAYDAT) = MONTH(@Ngay)
	AND YEAR(NGAYDAT) = YEAR(@Ngay) AND LOAIGD = @LoaiGD AND SOLUONG > 0 
	ORDER BY GIADAT DESC, NGAYDAT
END
ELSE
BEGIN
	SET @OutCrsr = CURSOR KEYSET FOR 
	SELECT ID,NGAYDAT,SOLUONG,GIADAT FROM dbo.LENHDAT
	WHERE MACP = @macp
	AND DAY(NGAYDAT) = DAY(@Ngay) AND MONTH(NGAYDAT) = MONTH(@Ngay)
	AND YEAR(NGAYDAT) = YEAR(@Ngay) AND LOAIGD = @LoaiGD AND SOLUONG > 0 
	ORDER BY GIADAT, NGAYDAT
END

OPEN @OutCrsr
GO
/****** Object:  StoredProcedure [dbo].[SP_KHOPLENH_LO]    Script Date: 4/26/2022 5:15:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[SP_KHOPLENH_LO]
@iddat int, @macp NVARCHAR(10), @Ngay NVARCHAR(10), @LoaiGD CHAR, @soluongMB INT, @giadatMB FLOAT
AS
SET DATEFORMAT DMY
DECLARE @trangThaiKhop BIT SET @trangThaiKhop = 0;
DECLARE @CrsrVar CURSOR, @idkhop INT, @ngaydat DATETIME, @soluong INT, @giadat FLOAT, @soluongkhop INT, @giakhop FLOAT
IF (@LoaiGD = 'B')
BEGIN
	EXEC CURSORLoaiGD @CrsrVar OUTPUT,@macp,@Ngay,'M'
END
ELSE
BEGIN
	EXEC CURSORLoaiGD @CrsrVar OUTPUT, @macp, @Ngay,'B'
END
FETCH NEXT FROM @CrsrVar INTO @idkhop, @ngaydat, @soluong, @giadat
WHILE (@@FETCH_STATUS <> -1 AND @soluongMB > 0)
BEGIN
	-- TRUONG HOP DAT LENH BAN
	IF (@LoaiGD = 'B')
	BEGIN
		-- BAN DUOC
		IF (@giadatMB <= @giadat)
		BEGIN
			-- SO LUONG LENH BAN LON HON SO LUONG LENH MUA TRONG DB
			IF (@soluongMB >= @soluong)
			BEGIN
				SET @soluongkhop = @soluong
				SET @giakhop = @giadat
				SET @soluongMB = @soluongMB - @soluong
				UPDATE dbo.LENHDAT SET SOLUONG = 0,
				TRANGTHAILENH = N'Khớp hết'
				WHERE CURRENT OF @CrsrVar
			END
			-- SO LUONG LENH BAN NHO HON SO LUONG LENH MUA TRONG DB
			ELSE
            BEGIN
                SET @soluongkhop = @soluongMB
				SET @giakhop = @giadat
				-- TINH SO LUONG CON LAI
				UPDATE dbo.LENHDAT SET SOLUONG = SOLUONG - @soluongMB,
				TRANGTHAILENH = N'Khớp lệnh 1 phần'
				WHERE CURRENT OF @CrsrVar
				SET @soluongMB = 0
            END
			INSERT INTO LENHKHOP(NGAYKHOP, SOLUONGKHOP, GIAKHOP, IDLENHDAT) VALUES (GETDATE(), @soluongkhop, @giakhop, @idkhop)
			INSERT INTO LENHKHOP(NGAYKHOP, SOLUONGKHOP, GIAKHOP, IDLENHDAT) VALUES (GETDATE(), @soluongkhop, @giakhop, @iddat)
			SET @trangThaiKhop = 1
			FETCH NEXT FROM @CrsrVar INTO @idkhop, @ngaydat, @soluong, @giadat
        END
		ELSE GOTO THOAT
	END
	-- TRUONG HOP DAT LENH MUA
	ELSE
	BEGIN
		-- MUA DUOC
		IF (@giadatMB >= @giadat)
		BEGIN
			-- SO LUONG MUA >= SO LUONG BAN
			IF (@soluongMB >= @soluong)
			BEGIN
				SET @soluongkhop = @soluong
				SET @giakhop = @giadat
				SET @soluongMB = @soluongMB - @soluong
				UPDATE dbo.LENHDAT SET SOLUONG = 0,
				TRANGTHAILENH = N'Khớp hết'
				WHERE CURRENT OF @CrsrVar
			END
			-- SO LUONG MUA NHO HON SO LUONG BAN
			ELSE
            BEGIN
                SET @soluongkhop = @soluongMB
				SET @giakhop = @giadat
				-- TINH SO LUONG CON LAI
				UPDATE dbo.LENHDAT SET SOLUONG = SOLUONG - @soluongMB,
				TRANGTHAILENH = N'Khớp lệnh 1 phần'
				WHERE CURRENT OF @CrsrVar
				SET @soluongMB = 0
            END
			INSERT INTO LENHKHOP(NGAYKHOP, SOLUONGKHOP, GIAKHOP, IDLENHDAT) VALUES (GETDATE(), @soluongkhop, @giakhop, @idkhop)
			INSERT INTO LENHKHOP(NGAYKHOP, SOLUONGKHOP, GIAKHOP, IDLENHDAT) VALUES (GETDATE(), @soluongkhop, @giakhop, @iddat)
			SET @trangThaiKhop = 1
			FETCH NEXT FROM @CrsrVar INTO @idkhop, @ngaydat, @soluong, @giadat
		END
		ELSE GOTO THOAT
	END
END
THOAT:
	-- TRUONG HOP VAN CON DU SO LUONG
	IF (@soluongMB > 0)
	BEGIN
		IF (@trangThaiKhop = 1) -- CO KHOP VOI IT NHAT 1 LENH
		BEGIN
			UPDATE LENHDAT SET SOLUONG = @soluongMB, TRANGTHAILENH = N'Khớp lệnh 1 phần' WHERE ID = @iddat
		END
	END
	ELSE -- TRUONG HOP SO LUONG = 0 (HET)
	BEGIN
		UPDATE LENHDAT SET SOLUONG = @soluongMB, TRANGTHAILENH = N'Khớp hết' WHERE ID = @iddat
	END
	CLOSE @CrsrVar
	DEALLOCATE @CrsrVar
GO
