-- Reset votes table and policies
DROP TABLE IF EXISTS votes CASCADE;

-- Recreate votes table with proper constraints
CREATE TABLE votes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  poll_id UUID REFERENCES polls(id) ON DELETE CASCADE NOT NULL,
  option_id UUID REFERENCES options(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  CONSTRAINT votes_poll_id_user_id_key UNIQUE (poll_id, user_id)
);

-- Create indexes
CREATE INDEX votes_poll_user_idx ON votes(poll_id, user_id);
CREATE INDEX votes_option_poll_idx ON votes(option_id, poll_id);

-- Enable RLS
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Create simple policies
CREATE POLICY "Anyone can view votes"
  ON votes FOR SELECT
  USING (true);

CREATE POLICY "Users can vote"
  ON votes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM polls
      WHERE id = poll_id
      AND is_active = true
      AND ends_at > NOW()
    )
  );

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE votes;