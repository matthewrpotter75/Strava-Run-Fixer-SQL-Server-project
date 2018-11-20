CREATE PROCEDURE dbo.FixAllRunPoints
(
	@GPXFilename VARCHAR(1000),
	@RunDate VARCHAR(8) = NULL,
	@RunName VARCHAR(500) = NULL,
	@Debug TINYINT = 0
)
AS
BEGIN

	SET NOCOUNT ON;

	BEGIN TRY

		DECLARE @ErrorMessage NVARCHAR(MAX),
				@ErrorSeverity INT,
				@ErrorState INT;

		DECLARE @MovingTime TIME,
				@TableName VARCHAR(100),
				@LoopCounter INT = 1,
				@NumPoints INT,
				@SQL NVARCHAR(2000);

		CREATE TABLE #PointsToBeCorrected
		(
			Id INT IDENTITY(1,1) NOT NULL,
			MovingTime TIME NOT NULL
		);

		IF @RunDate IS NULL
			SELECT @RunDate = FORMAT(GETDATE(), 'yyyyMMdd');

		IF @RunName IS NULL AND @RunDate IS NOT NULL
			SELECT @RunName = REPLACE(REPLACE(REPLACE(@GPXFilename,'it_s_','it''s '),'_',' '),'.gpx','');

		EXEC dbo.CreateAndLoadGPXFile 
		@GPXFilename = @GPXFilename, 
		@RunDate = @RunDate,
		@Debug= @Debug;

		SET @SQL = 
		'INSERT INTO #PointsToBeCorrected
		(MovingTime)
		SELECT @MovingTime = MovingTime
		FROM ' + @TableName + '
		WHERE DiffTime > 5
		ORDER BY MovingTime DESC;'

		EXEC sp_executesql @SQL;

		SELECT @NumPoints = COuNT(1)
		FROM #PointsToBeCorrected;

		WHILE @LoopCounter <= @NumPoints
		BEGIN

			EXEC dbo.RemoveRunPointsAndAdjustRemainingRunPoints
			@TableName = @TableName,
			@StartDeleteMovingTime = @MovingTime,
			@EndDeleteMovingTime = @MovingTime,
			@IsAdjustHR = 1;

		END

		EXEC dbo.OutputRunGPX
		@Tablename = @TableName,
		@RunName = @RunName,
		@Debug= @Debug;

	END TRY
	BEGIN CATCH

		SET @ErrorMessage  = ERROR_MESSAGE();
		SET @ErrorSeverity = ERROR_SEVERITY();
		SET @ErrorState    = ERROR_STATE();

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

	END CATCH

END