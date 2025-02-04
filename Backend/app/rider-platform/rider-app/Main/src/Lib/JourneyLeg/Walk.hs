{-# OPTIONS_GHC -Wno-orphans #-}

module Lib.JourneyLeg.Walk where

import qualified Domain.Types.WalkLegMultimodal as DWalkLeg
import Kernel.Prelude
import Kernel.Types.Error
import Kernel.Utils.Common
import qualified Lib.JourneyLeg.Types as JLT
import Lib.JourneyLeg.Types.Walk
import qualified Lib.JourneyModule.Types as JT
import SharedLogic.Search
import qualified Storage.Queries.WalkLegMultimodal as QWalkLeg

instance JT.JourneyLeg WalkLegRequest m where
  search (WalkLegRequestSearch WalkLegRequestSearchData {..}) = do
    fromLocation <- buildSearchReqLoc parentSearchReq.merchantId parentSearchReq.merchantOperatingCityId origin
    toLocation <- buildSearchReqLoc parentSearchReq.merchantId parentSearchReq.merchantOperatingCityId destination
    now <- getCurrentTime
    id <- generateGUID
    let journeySearchData =
          JLT.JourneySearchData
            { journeyId = journeyLegData.journeyId.getId,
              journeyLegOrder = journeyLegData.sequenceNumber,
              agency = journeyLegData.agency <&> (.name),
              skipBooking = False,
              convenienceCost = 0,
              pricingId = Nothing
            }
    let walkLeg =
          DWalkLeg.WalkLegMultimodal
            { id,
              estimatedDistance = journeyLegData.distance,
              estimatedDuration = Just journeyLegData.duration,
              fromLocation = fromLocation,
              toLocation = Just toLocation,
              journeyLegInfo = Just journeySearchData,
              riderId = parentSearchReq.riderId,
              startTime = fromMaybe now journeyLegData.fromArrivalTime,
              merchantId = parentSearchReq.merchantId,
              status = DWalkLeg.InPlan,
              merchantOperatingCityId = parentSearchReq.merchantOperatingCityId,
              createdAt = now,
              updatedAt = now
            }
    QWalkLeg.createWalkLeg walkLeg
    return $ JT.SearchResponse {id = id.getId}
  search _ = throwError (InternalError "Not supported")

  confirm (WalkLegRequestConfirm _) = return ()
  confirm _ = throwError (InternalError "Not supported")

  update (WalkLegRequestUpdate _) = return ()
  update _ = throwError (InternalError "Not supported")

  cancel (WalkLegRequestCancel _) = return ()
  cancel _ = throwError (InternalError "Not supported")

  getState (WalkLegRequestGetState req) = do
    legData <- QWalkLeg.findById req.walkLegId >>= fromMaybeM (InvalidRequest "WalkLeg Data not found")
    journeyLegInfo <- legData.journeyLegInfo & fromMaybeM (InvalidRequest "WalkLeg journey legInfo data missing")
    let status = JT.getWalkLegStatusFromWalkLeg legData journeyLegInfo
    return $ JT.JourneyLegState {status = status, currentPosition = Nothing, legOrder = journeyLegInfo.journeyLegOrder}
  getState _ = throwError (InternalError "Not supported")

  getInfo (WalkLegRequestGetInfo req) = do
    legData <- QWalkLeg.findById req.walkLegId >>= fromMaybeM (InvalidRequest "WalkLeg Data not found")
    JT.mkWalkLegInfoFromWalkLegData legData
  getInfo _ = throwError (InternalError "Not supported")

  getFare (WalkLegRequestGetFare _) = do
    return $
      Just $
        JT.GetFareResponse
          { estimatedMinFare = HighPrecMoney {getHighPrecMoney = 0},
            estimatedMaxFare = HighPrecMoney {getHighPrecMoney = 0}
          }
  getFare _ = throwError (InternalError "Not supported")
