



IF (OBJECT_ID('[CalculateNewMilkRate]', 'TF') is not null)
BEGIN
    DROP FUNCTION [dbo].[CalculateNewMilkRate]
END;
GO

create FUNCTION [dbo].[CalculateNewMilkRate] (
	@fatvalue DECIMAL(18, 2)
	,@weight DECIMAL(18, 2)
	,@animal NVARCHAR
	)
RETURNS @fin TABLE (
	NewRate DECIMAL(18, 2) NOT NULL
	,NewAmt DECIMAL(18, 2) NOT NULL
	,NewMemberRate DECIMAL(18, 2) NOT NULL
	)
AS
BEGIN
	DECLARE @rate AS DECIMAL(18, 2) = 0
	DECLARE @perLtrRate AS DECIMAL(18, 2) = 0
	DECLARE @SNF AS DECIMAL(18, 2) = 8.5
	DECLARE @commission DECIMAL(18, 2) = 0
	DECLARE @snfvalue DECIMAL(18, 2) = 0
	DECLARE @NewRate AS DECIMAL(18, 2) = 0
	DECLARE @NewAmt AS DECIMAL(18, 2) = 0
	DECLARE @maxfat AS DECIMAL(18, 2) = 0
	DECLARE @maxrate AS DECIMAL(18, 2) = 0
		DECLARE @bonusbufffat AS DECIMAL(18, 2) = 0
		DECLARE @bonusbuff AS DECIMAL(18, 2) = 0
			DECLARE @bonusamt AS DECIMAL(18, 2) = 0
	SET @maxfat = dbo.GetMaxFatLatest(@animal)
	SET @maxrate = dbo.GetMaxRateLatest(@animal)
	
	BEGIN
		SELECT TOP 1 @rate = Rate11
			,@commission = (
				CASE 
					WHEN @animal = 'c'
						THEN CommissionCow
					WHEN @animal = 'b'
						THEN CommissionBuff
					END
				)
				,

				@bonusbufffat = BonusStartingFatBuff
				,@bonusbuff = BonusBuff

		FROM Mst_MilkRate
		WHERE cast(ApprovalDate AS DATE) = (
				SELECT cast(MAX(ApprovalDate) AS DATE)
				FROM Mst_MilkRate
				WHERE cast(ApprovalDate AS DATE) <= '2018-01-01'
					AND RateType = 's'
					AND IsActive = 1
					AND IsDelete = 0
				)
			AND RateType = 's'
			AND IsActive = 1
			AND IsDelete = 0
			AND milk = @animal
			AND FromFat <= @fatvalue
			AND ToFat >= @fatvalue
	END

	IF (@rate = 0)
	BEGIN
		SET @rate = @maxrate
		SET @fatvalue = @maxfat
	END
	if(@animal = 'c')
	begin
	SET @NewRate = cast((@rate * (@fatvalue + (@snf * 0.66)) / 100 - 0.25) AS DECIMAL(18, 2))
	SET @NewAmt = cast((@weight * @NewRate) AS DECIMAL(18, 2))
	end
	ELSE 
	IF(@animal = 'b')
	begin

	

	
	if(@fatvalue <= @bonusbufffat)
	begin
	
	SET @NewRate = cast((@rate * (@fatvalue) / 100 - 0.25) AS DECIMAL(18, 2))
	end
	else
	begin
	SET @NewRate = cast(((@bonusbufffat * @rate) / 100 - 0.25) AS DECIMAL(18, 2))
	set @bonusamt = cast(((((@fatvalue - @bonusbufffat)*10) * @bonusbuff)) AS DECIMAL(18, 2))
	SET @NewRate = @NewRate + @bonusamt ;
	end

	SET @NewAmt = cast((@weight * @NewRate) AS DECIMAL(18, 2))
	end

	INSERT INTO @fin (
		NewRate
		,NewAmt
		,NewMemberRate
		)
	VALUES (
		@NewRate
		,@NewAmt
		,@rate
		)

	RETURN;
END
GO
IF (OBJECT_ID('[GetMaxFatLatest]', 'FN') is not null)
BEGIN
    DROP FUNCTION [dbo].[GetMaxFatLatest]
END;
GO
CREATE FUNCTION [dbo].[GetMaxFatLatest]

(
@animle as nvarchar=''

)
RETURNS decimal(18,2)
AS
BEGIN
declare @maxfat as decimal(18,2)=0
begin
set @maxfat = (SELECT max(ToFat)  FROM Mst_MilkRate
		WHERE cast(ApprovalDate AS DATE) = (
				SELECT cast(MAX(ApprovalDate) AS DATE)
				FROM Mst_MilkRate
				WHERE cast(ApprovalDate AS DATE) <= '2018-01-01'
					AND RateType = 's'
					AND IsActive = 1
					AND IsDelete = 0
				
				)
			AND RateType = 's'
			AND IsActive = 1
			AND IsDelete = 0
		and milk = @animle)
		
	
END
if(@maxfat is not null)
return @maxfat
return 0
END

GO

IF (OBJECT_ID('[GetMaxRateLatest]', 'FN') is not null)
BEGIN
    DROP FUNCTION [dbo].[GetMaxRateLatest]
END;
GO

CREATE FUNCTION [dbo].[GetMaxRateLatest]

(
@animle as nvarchar=''

)
RETURNS decimal(18,2)
AS
BEGIN
declare @maxrate as decimal(18,2)=0
begin
set @maxrate = (SELECT max(Rate11)  FROM Mst_MilkRate
		WHERE cast(ApprovalDate AS DATE) = (
				SELECT cast(MAX(ApprovalDate) AS DATE)
				FROM Mst_MilkRate
				WHERE cast(ApprovalDate AS DATE) <= '2018-01-01'
					AND RateType = 's'
					AND IsActive = 1
					AND IsDelete = 0
				
				)
			AND RateType = 's'
			AND IsActive = 1
			AND IsDelete = 0
		and milk = @animle)
		
	
END
if(@maxrate is not null)
return @maxrate
return 0
END
GO


IF (OBJECT_ID('SpMilkRateChangeTool', 'P') is not null)
BEGIN
    DROP PROCEDURE [dbo].[SpMilkRateChangeTool]
	DROP TYPE [dbo].[Trans_MilkPurchaseG]
END;
GO


CREATE TYPE [dbo].[Trans_MilkPurchaseG] AS TABLE(
	[SrNo.1] [int] NULL,
	[SrNo.] [int] NOT NULL,
	[MemberCode] [nvarchar](20) NULL,
	[Animal] [nvarchar](10) NULL,
	[Date] [datetime] NULL,
	[Shift] [nvarchar](20) NULL,
	[Quantity] [decimal](18, 2) NULL,
	[Fat] [decimal](18, 2) NULL,
	[SNF] [decimal](18, 2) NULL,
	[Rate] [decimal](18, 2) NULL,
	[NewRate] [decimal](18, 2) NULL,
	[Amount] [decimal](18, 2) NULL,
	[NewAmount] [decimal](18, 2) NULL,
	[MemberRate] [decimal](18, 2) NULL,
	[NewMemberRate] [decimal](18, 2) NULL
)
GO


CREATE PROCEDURE [dbo].[SpMilkRateChangeTool] 
@mode NVARCHAR(50) = ''
	,@FrmDate AS DATETIME = ''
	,@ToDate AS DATETIME = ''
	,@Rate AS DECIMAL(18, 2) = 0.0
	,@amount AS DECIMAL(18, 2) = 0.0
	,@milkQty AS DECIMAL(18, 2) = 0.0
	,@MemberRate AS DECIMAL(18, 2) = 0.0
	,@Dairyrate AS DECIMAL(18, 2) = 0.0
	,@date AS DATETIME = ''
	,@memberCode AS NVARCHAR(20) = ''
	,@UpdatebyId INT = 0
	,@shift AS NVARCHAR(20) = ''
	,@FillUpId as int=0
	,@NewTab as dbo.Trans_MilkPurchaseG readonly
	
AS
BEGIN
	IF @mode = 'getShabhashadWiseDataForRateChange'
		SELECT 0 + ROW_NUMBER() OVER (
				ORDER BY FillUpId
				) AS [SrNo.1]
			,FillupId as [SrNo.]
			,MemberCode
			,Animal
			,[Date]
			,[Shift]
			,MilkQuantity AS [Quantity]
			,Fat
			,SNF
			
			,Rate
			,Cast(N1.NewRate AS DECIMAL(18, 2)) AS NewRate
			,Amount
			,Cast(N1.NewAmt AS DECIMAL(18, 2)) AS NewAmount
			,MemberRate
			,Cast(N1.NewMemberRate AS DECIMAL(18, 2)) AS NewMemberRate
			
		FROM Trans_MilkPurchase DMP
		INNER JOIN Mst_Shabhashad SM ON DMP.MemberCode = SM.Member_Code
		CROSS APPLY dbo.CalculateNewMilkRate(DMP.FAT,DMP.MilkQuantity,cast(DMP.Animal as nvarchar(1)) ) N1 
		WHERE CAST(DMP.DATE AS DATE) BETWEEN @FrmDate
				AND @ToDate
			AND SM.IsDelete = 0
			AND SM.IsActive = 1
			AND DMP.IsDelete = 0

	IF @mode = 'updateData'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION

		UPDATE F
			SET F.Amount = Cast(N1.NewAmt AS DECIMAL(18, 2))
				,F.Rate = Cast(N1.NewRate AS DECIMAL(18, 2))
				,F.IsUpdate = 1
				,F.IsUpload = 0
				,F.UpdateDate = GETDATE()
				,F.MemberRate = Cast(N1.NewMemberRate AS DECIMAL(18, 2))
				,F.Dairyrate = @Dairyrate
				,F.UpdatedBy = @UpdatebyId
			FROM
				Trans_MilkPurchase F
				CROSS APPLY dbo.CalculateNewMilkRate(F.FAT,F.MilkQuantity,cast(F.Animal as nvarchar(1)) ) N1 
				WHERE FillUpId=@FillUpId

			UPDATE Trans_ILedger
			SET Amount = @amount
				,Rate = @Rate
				,UpdationDate = GETDATE()  
			WHERE ShabhashadId = @memberCode
				AND CAST(DATE AS DATE) =@date
				AND Shift = @shift

			COMMIT TRANSACTION
		END TRY

		BEGIN CATCH
			ROLLBACK TRANSACTION THROW
		END CATCH
	END
	IF @mode = 'updateTable'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION

		UPDATE Trans_MilkPurchase
			SET Amount = Cast(T.NewAmount AS DECIMAL(18, 2))
				,Rate = Cast(T.NewRate AS DECIMAL(18, 2))
				,IsUpdate = 1
				,IsUpload = 0
				,UpdateDate = GETDATE()
				,MemberRate = Cast(T.NewMemberRate AS DECIMAL(18, 2))
				,UpdatedBy = @UpdatebyId
			FROM @NewTab T
				 WHERE FillUpId=T.[SrNo.]
				 				
			UPDATE Trans_ILedger
			SET Amount = Cast(T.NewAmount AS DECIMAL(18, 2))
				,Rate = Cast(T.NewRate AS DECIMAL(18, 2))
				,UpdationDate = GETDATE()  
			FROM @NewTab T
			WHERE ShabhashadId = T.MemberCode
				AND CAST(Trans_ILedger.Date AS DATE) =CAST(T.Date AS DATE)
				AND Trans_ILedger.[Shift] = T.[Shift]
			COMMIT TRANSACTION
		END TRY

		BEGIN CATCH
			ROLLBACK TRANSACTION THROW
		END CATCH
	END

	

END
GO


