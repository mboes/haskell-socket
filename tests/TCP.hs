{-# LANGUAGE OverloadedStrings, ScopedTypeVariables, TypeFamilies, FlexibleContexts #-}
module Main where

import Data.Monoid
import Control.Monad
import Control.Exception
import Control.Concurrent
import Control.Concurrent.Async
import Foreign.Storable
import System.Socket
import System.Socket.Family.Inet
import System.Socket.Family.Inet6
import System.Socket.Type.Stream
import System.Socket.Protocol.TCP
import System.Exit

main :: IO ()
main = do
  test "test0001.01" $ test0001 (undefined :: Socket Inet  Stream TCP)  localhost
  test "test0001.02" $ test0001 (undefined :: Socket Inet6 Stream TCP)  localhost6

-- Test send and receive on connection oriented sockets (i.e. TCP).
test0001 :: (Family f, Type t, Protocol p, Storable (SocketAddress f)) => Socket f t p -> SocketAddress f -> IO (Either String String)
test0001 dummy addr =
  bracket
      ( do  server <- socket `asTypeOf` return dummy  `onException` print "E01"
            client <- socket `asTypeOf` return dummy  `onException` print "E02"
            return (server, client)
      )
      (\(server,client)-> do
            close server                              `onException` print "E03"
            close client                              `onException` print "E04"
      )
      (\(server,client)-> do
            setSocketOption server (ReuseAddress True)     `onException` print "E05"
            bind server addr                          `onException` print "E06"
            listen server 5                           `onException` print "E07"
            serverRecv <- async $ do
              (peerSock, peerAddr) <- accept server   `onException` print "E08"
              receive peerSock 4096 mempty               `onException` print "E09"
            connect client addr                       `onException` print "E11"
            send client helloWorld mempty             `onException` print "E12"
            msg <- wait serverRecv                    `onException` print "E13"
            close server                              `onException` print "E14"
            close client                              `onException` print "E15"
            if (msg /= helloWorld)
              then return (Left  "Received message was bogus.")
              else return (Right "")
      )
  where
    helloWorld = "Hello world!"

localhost :: SocketAddress Inet
localhost =  SocketAddressInet inetLoopback 7777

localhost6 :: SocketAddress Inet6
localhost6 = SocketAddressInet6 inet6Loopback 7777 0 0


test :: String -> IO (Either String String) -> IO ()
test n t = do
  putStr ("Test " ++ show n ++ ": ")
  catch
    ( do  r <- t
          case r of
            Left  x -> putStr "FAIL " >> putStrLn x >> exitFailure
            Right x -> putStr "OK   " >> putStrLn x
    )
    (\e-> putStr "EXCP " >> putStrLn (show (e :: SomeException)) >> exitFailure)
