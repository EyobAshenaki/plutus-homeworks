{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoImplicitPrelude #-}

module MintBurn where

import Plutus.V1.Ledger.Value (isZero, split)
import Plutus.V2.Ledger.Api
  ( BuiltinData,
    CurrencySymbol,
    MintingPolicy,
    PubKeyHash,
    ScriptContext (scriptContextTxInfo),
    TxInfo (txInfoMint),
    mkMintingPolicyScript,
  )
import Plutus.V2.Ledger.Contexts (txSignedBy)
import qualified PlutusTx
import PlutusTx.Prelude (Bool (False, True), fst, not, traceIfFalse, ($), (.), (||))
import Text.Printf (printf)
import Utilities
  ( currencySymbol,
    wrapPolicy,
    writeCodeToFile,
    writePolicyToFile,
  )
import Prelude (IO, Show (show))

{-# INLINEABLE mkMintBurnPolicy #-}
mkMintBurnPolicy :: PubKeyHash -> () -> ScriptContext -> Bool
mkMintBurnPolicy pkh () ctx =
  traceIfFalse "*** Missing signature ***" hasSigned
    || traceIfFalse "*** Invalid signature to Mint ***" burnToken
  where
    info :: TxInfo
    info = scriptContextTxInfo ctx

    hasSigned :: Bool
    hasSigned = txSignedBy info pkh

    -- Returns True if the token is being burned
    burnToken :: Bool
    burnToken = not $ isZero $ fst $ split $ txInfoMint info

{-# INLINEABLE mkWrappedMintBurnPolicy #-}
mkWrappedMintBurnPolicy :: BuiltinData -> BuiltinData -> BuiltinData -> ()
mkWrappedMintBurnPolicy pkh = wrapPolicy (mkMintBurnPolicy $ PlutusTx.unsafeFromBuiltinData pkh)

mintBurnCode :: PlutusTx.CompiledCode (BuiltinData -> BuiltinData -> BuiltinData -> ())
mintBurnCode = $$(PlutusTx.compile [||mkWrappedMintBurnPolicy||])

mintBurnPolicy :: PubKeyHash -> MintingPolicy
mintBurnPolicy pkh = mkMintingPolicyScript $ mintBurnCode `PlutusTx.applyCode` PlutusTx.liftCode (PlutusTx.toBuiltinData pkh)

---------------------------------------------------------------------------------------------------
------------------------------------- HELPER FUNCTIONS --------------------------------------------

savemintBurnCode :: IO ()
savemintBurnCode = writeCodeToFile "assets/mintBurn.plutus" mintBurnCode

saveMintBurnPolicy :: PubKeyHash -> IO ()
saveMintBurnPolicy pkh = writePolicyToFile (printf "assets/mintBurn-%s.plutus" $ show pkh) $ mintBurnPolicy pkh

mintBurnCurrencySymbol :: PubKeyHash -> CurrencySymbol
mintBurnCurrencySymbol = currencySymbol . mintBurnPolicy
