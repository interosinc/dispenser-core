{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NoImplicitPrelude     #-}

module Dispenser.TransportExample where

import Dispenser.Prelude hiding ( ThreadId )

data ExampleEvent
  = MessagePosted PostedMessage
  | ThreadCreated CreatedThread
  deriving (Eq, Generic, Ord, Read, Show)

data PostedMessage = PostedMessage
  { _postedMessageUsername :: Username
  , _postedMessageThreadId :: ThreadId
  } deriving (Eq, Generic, Ord, Read, Show)

data CreatedThread = CreatedThread
  { _createdThreadUsername    :: Username
  , _createdThreadThreadTitle :: ThreadTitle
  , _createdThreadBody        :: ThreadBody
  , _createdThreadCreatedAt   :: Timestamp
  } deriving (Eq, Generic, Ord, Read, Show)

data UserProjection = UserProjection
  { _userProjectionUsername :: Username
  , _userProjectionPosts    :: [Post]
  } deriving (Eq, Generic, Ord, Read, Show)

data ThreadProjection = ThreadProjection
  { _threadProjectionThreadSlug :: Slug
  , _threadProjectionPosts      :: [Post]
  } deriving (Eq, Generic, Ord, Read, Show)

data Post = Post
  { _postPostId    :: PostId
  , _postUsername  :: Username
  , _postBody      :: PostBody
  , _postCreatedAt :: Timestamp
  } deriving (Eq, Generic, Ord, Read, Show)

type PostBody    = Text
type PostId      = UUID
type Slug        = Text
type ThreadBody  = Text
type ThreadId    = UUID
type ThreadTitle = Text
type Timestamp   = UTCTime
type UUID        = Text
type Username    = Text
