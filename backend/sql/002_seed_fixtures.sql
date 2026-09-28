-- Generic TV2 fixtures. They validate platform behavior and must never be treated
-- as product-specific business logic.

INSERT INTO listings(country_code,list_number,tldx,display_name,entity_type,template_key,resolution_state)
VALUES
 ('1','529',NULL,'TV2 Fixture Alpha','person','basic','active'),
 ('1','5291',NULL,'TV2 Fixture Alpha Branch','business','basic','active'),
 ('1','529','411','TV2 Fixture Alpha Catalogue','organization','basic','active'),
 ('91','529',NULL,'TV2 Fixture India Namespace','business','basic','active'),
 (NULL,'529',NULL,'TV2 Global Fixture','organization','basic','active'),
 ('1','700@12',NULL,'TV2 Symbol Fixture','business','basic','active')
ON CONFLICT DO NOTHING;

INSERT INTO listing_resources(listing_id,resource_key,resource_type,public_uri)
SELECT id,'web','web','https://example.com/alpha' FROM listings WHERE country_code='1' AND list_number='529' AND tldx IS NULL
UNION ALL SELECT id,'call','call',NULL FROM listings WHERE country_code='1' AND list_number='529' AND tldx IS NULL
UNION ALL SELECT id,'video_call','video_call',NULL FROM listings WHERE country_code='1' AND list_number='529' AND tldx IS NULL
UNION ALL SELECT id,'text','text',NULL FROM listings WHERE country_code='1' AND list_number='529' AND tldx IS NULL
UNION ALL SELECT id,'web','web','https://example.com/alpha-branch' FROM listings WHERE country_code='1' AND list_number='5291' AND tldx IS NULL
UNION ALL SELECT id,'web','web','https://example.com/alpha/catalogue' FROM listings WHERE country_code='1' AND list_number='529' AND tldx='411'
UNION ALL SELECT id,'video','video','https://example.com/media/video.mp4' FROM listings WHERE country_code='91' AND list_number='529' AND tldx IS NULL
UNION ALL SELECT id,'image','image','https://example.com/media/image.jpg' FROM listings WHERE country_code='1' AND list_number='700@12' AND tldx IS NULL
ON CONFLICT (listing_id,resource_key) DO NOTHING;

INSERT INTO listing_buttons(listing_id,slot,label,resource_id)
SELECT r.listing_id,1,'CALL',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='1' AND l.list_number='529' AND l.tldx IS NULL AND r.resource_key='call'
UNION ALL SELECT r.listing_id,2,'TEXT',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='1' AND l.list_number='529' AND l.tldx IS NULL AND r.resource_key='text'
UNION ALL SELECT r.listing_id,3,'VIDEO',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='1' AND l.list_number='529' AND l.tldx IS NULL AND r.resource_key='video_call'
UNION ALL SELECT r.listing_id,4,'WEB',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='1' AND l.list_number='529' AND l.tldx IS NULL AND r.resource_key='web'
UNION ALL SELECT r.listing_id,1,'WEB',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='1' AND l.list_number='5291' AND l.tldx IS NULL AND r.resource_key='web'
UNION ALL SELECT r.listing_id,1,'OPEN',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='1' AND l.list_number='529' AND l.tldx='411' AND r.resource_key='web'
UNION ALL SELECT r.listing_id,1,'VIDEO',r.id FROM listing_resources r JOIN listings l ON l.id=r.listing_id
 WHERE l.country_code='91' AND l.list_number='529' AND l.tldx IS NULL AND r.resource_key='video'
ON CONFLICT (listing_id,slot) DO NOTHING;
