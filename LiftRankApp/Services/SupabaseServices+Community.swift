import Foundation
import Supabase

@MainActor
final class SupabaseCommunityService: CommunityService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    func communities() async throws -> [ForumCommunity] { do { let rows: [ForumCommunityDTO] = try await client.from("forum_communities").select().order("name").execute().value; return rows.map(\.community) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func posts(in destination: ForumDestination?) async throws -> [ForumPost] {
        do {
            var query = client.from("forum_posts").select()
            if let id = destination?.communityID { query = query.eq("community_id", value: id) }
            if let id = destination?.gymID { query = query.eq("gym_id", value: id) }
            let rows: [ForumPostDTO] = try await query.order("created_at", ascending: false).execute().value
            let votes: [ForumPostVoteDTO] = try await client.from("forum_post_votes").select().execute().value
            let saves: [ForumPostUserDTO] = try await client.from("forum_post_saves").select("post_id,user_id").execute().value
            let watches: [ForumPostUserDTO] = try await client.from("forum_post_watches").select("post_id,user_id").execute().value
            let comments: [ForumCommentDTO] = try await client.from("forum_comments").select().execute().value
            var result: [ForumPost] = []
            for row in rows {
                let card = try? await SupabaseProfileService(client: client).profileCard(userID: row.authorID)
                result.append(row.post(
                    authorName: card?.displayName ?? card?.username ?? "Member",
                    commentCount: comments.filter { $0.postID == row.id && $0.removedAt == nil }.count,
                    votes: Dictionary(uniqueKeysWithValues: votes.filter { $0.postID == row.id }.map { ($0.userID, $0.vote) }),
                    saves: Set(saves.filter { $0.postID == row.id }.map(\.userID)),
                    watches: Set(watches.filter { $0.postID == row.id }.map(\.userID))
                ))
            }
            return result
        } catch { throw SupabaseServiceErrorMapper.map(error) }
    }
    func comments(for post: ForumPost) async throws -> [ForumComment] { do { let rows: [ForumCommentDTO] = try await client.from("forum_comments").select().eq("post_id", value: post.id).order("created_at").execute().value; let votes: [ForumCommentVoteDTO] = try await client.from("forum_comment_votes").select().execute().value; var result:[ForumComment]=[]; for row in rows { let card = try? await SupabaseProfileService(client: client).profileCard(userID: row.authorID); result.append(row.comment(authorName: card?.displayName ?? "Member", votes: Dictionary(uniqueKeysWithValues: votes.filter{$0.commentID==row.id}.map{($0.userID,$0.vote)}))) }; return result } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func join(community: ForumCommunity, note: String) async throws -> ForumMembershipStatus? { do { let value:String = try await client.rpc("join_forum_community", params:["target_community_id":community.id.uuidString,"request_note":note]).execute().value; return ForumMembershipStatus(rawValue:value) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func leave(community: ForumCommunity) async throws { do { try await client.rpc("leave_forum_community", params:["target_community_id":community.id]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func createPost(_ post: ForumPost) async throws -> Bool { do { let userID=try await client.auth.session.user.id; try await client.from("forum_posts").insert(ForumPostInsertDTO(post:post,userID:userID)).execute(); return true } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func addComment(to post: ForumPost, parentCommentID: UUID?, body: String) async throws -> ForumComment? { do { let userID=try await client.auth.session.user.id; let row:ForumCommentDTO=try await client.from("forum_comments").insert(ForumCommentInsertDTO(id:UUID(),postID:post.id,parentCommentID:parentCommentID,authorID:userID,body:body)).select().single().execute().value; return row.comment(authorName:"You",votes:[:]) } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func vote(post: ForumPost, vote: CommunityVote?) async throws { try await setVote(table:"forum_post_votes",targetColumn:"post_id",targetID:post.id,vote:vote) }
    func vote(comment: ForumComment, vote: CommunityVote?) async throws { try await setVote(table:"forum_comment_votes",targetColumn:"comment_id",targetID:comment.id,vote:vote) }
    func toggleSaved(post: ForumPost) async throws { try await togglePostUser(table:"forum_post_saves",post:post,currentlySet:post.savedByUserIDs) }
    func toggleWatched(post: ForumPost) async throws { try await togglePostUser(table:"forum_post_watches",post:post,currentlySet:post.watchedByUserIDs) }
    func vote(pollPost: ForumPost, optionID: UUID) async throws { do { let userID=try await client.auth.session.user.id;try await client.from("forum_poll_votes").upsert(ForumPollVoteDTO(postID:pollPost.id,optionID:optionID,userID:userID),onConflict:"post_id,user_id").execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func report(targetType: ForumReportTargetType, targetID: UUID, communityID: UUID?, reason: CommunityReportReason, note: String) async throws -> Bool { do { let userID=try await client.auth.session.user.id;try await client.from("forum_reports").upsert(ForumReportInsertDTO(communityID:communityID,targetType:targetType.rawValue,targetID:targetID,reporterID:userID,reason:reason.rawValue,note:note),onConflict:"target_type,target_id,reporter_id",ignoreDuplicates:true).execute();return true } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func moderate(post: ForumPost, action: ForumModerationActionKind, reason: String) async throws { do { try await client.rpc("moderate_forum_post",params:["target_post_id":post.id.uuidString,"action":action.rawValue,"reason":reason]).execute() } catch { throw SupabaseServiceErrorMapper.map(error) } }
    func threads() async throws -> [CommunityThread] { try await posts(in:nil).map { CommunityThread(id:$0.id,title:$0.title,body:$0.body,authorID:$0.authorID,authorName:$0.authorName,kind:.general,challengeID:$0.challengeID,gymID:$0.destination.gymID,replyCount:$0.commentCount,likeCount:max(0,$0.voteScore),createdAt:$0.createdAt,votes:$0.votes,isLocked:$0.isLocked,removedAt:$0.removedAt,removalReason:$0.removalReason,warning:nil) } }
    func replies(for thread: CommunityThread) async throws -> [CommunityThreadReply] { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id}) else{return []};return try await comments(for:post).map{CommunityThreadReply(id:$0.id,threadID:$0.postID,authorID:$0.authorID,authorName:$0.authorName,body:$0.body,createdAt:$0.createdAt,votes:$0.votes,removedAt:$0.removedAt)} }
    func createThread(_ thread: CommunityThread) async throws -> CommunityThread { guard let community=try await communities().first else{throw LiftRankServiceError.server("No community is available.")};let post=ForumPost(id:thread.id,destination:thread.gymID.map(ForumDestination.gym) ?? .community(community.id),authorID:thread.authorID,authorName:thread.authorName,kind:.discussion,title:thread.title,body:thread.body,tag:nil,attachments:[],poll:nil,liftID:nil,workoutID:nil,linkURL:nil,challengeID:thread.challengeID,createdAt:thread.createdAt,editedAt:nil,commentCount:0,votes:[:],savedByUserIDs:[],watchedByUserIDs:[],isPinned:false,isLocked:false,removedAt:nil,removalReason:nil);_ = try await createPost(post);return thread }
    func addReply(to thread: CommunityThread, body: String) async throws -> CommunityThreadReply? { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id}),let value=try await addComment(to:post,parentCommentID:nil,body:body)else{return nil};return CommunityThreadReply(id:value.id,threadID:thread.id,authorID:value.authorID,authorName:value.authorName,body:value.body,createdAt:value.createdAt,votes:value.votes,removedAt:value.removedAt) }
    func voteThread(_ thread: CommunityThread, vote: CommunityVote?) async throws { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id})else{return};try await self.vote(post:post,vote:vote) }
    func voteReply(_ reply: CommunityThreadReply, vote: CommunityVote?) async throws { let placeholder=ForumComment(id:reply.id,postID:reply.threadID,parentCommentID:nil,authorID:reply.authorID,authorName:reply.authorName,body:reply.body,createdAt:reply.createdAt,editedAt:nil,votes:reply.votes,removedAt:reply.removedAt,removalReason:nil);try await self.vote(comment:placeholder,vote:vote) }
    func report(targetType: CommunityReportTargetType, targetID: UUID, reason: CommunityReportReason, note: String) async throws { _ = try await report(targetType:targetType == .thread ? .post:.comment,targetID:targetID,communityID:nil,reason:reason,note:note) }
    func moderate(_ thread: CommunityThread, operation: CommunityModerationOperation, reason: String?) async throws { guard let post=try await posts(in:nil).first(where:{$0.id==thread.id})else{return};let action:ForumModerationActionKind = operation == .lock ? .lock : operation == .unlock ? .unlock : operation == .remove ? .remove : .restore;try await moderate(post:post,action:action,reason:reason ?? "") }

    private func setVote(table:String,targetColumn:String,targetID:UUID,vote:CommunityVote?) async throws { do { let userID=try await client.auth.session.user.id;if let vote{try await client.from(table).upsert(ForumVoteInsertDTO(targetColumn:targetColumn,targetID:targetID,userID:userID,value:vote.rawValue),onConflict:"\(targetColumn),user_id").execute()}else{try await client.from(table).delete().eq(targetColumn,value:targetID).eq("user_id",value:userID).execute()} } catch { throw SupabaseServiceErrorMapper.map(error) } }
    private func togglePostUser(table:String,post:ForumPost,currentlySet:Set<UUID>) async throws { do { let userID=try await client.auth.session.user.id;if currentlySet.contains(userID){try await client.from(table).delete().eq("post_id",value:post.id).eq("user_id",value:userID).execute()}else{try await client.from(table).insert(ForumPostUserDTO(postID:post.id,userID:userID)).execute()} } catch { throw SupabaseServiceErrorMapper.map(error) } }
}

private struct ForumCommunityDTO: Decodable {
    let id:UUID;let slug:String;let name:String;let summary:String;let details:String;let category:String;let symbolName:String;let accentHex:String;let visibility:String;let rules:[String];let availableTags:[String];let staffOwnerID:UUID?;let createdAt:Date;let archivedAt:Date?
    enum CodingKeys:String,CodingKey{case id,slug,name,summary,details,category,visibility,rules;case symbolName="symbol_name",accentHex="accent_hex",availableTags="available_tags",staffOwnerID="staff_owner_id",createdAt="created_at",archivedAt="archived_at"}
    var community:ForumCommunity{.init(id:id,slug:slug,name:name,summary:summary,details:details,category:category,symbolName:symbolName,accentHex:accentHex,visibility:ForumCommunityVisibility(rawValue:visibility) ?? .publicOpen,rules:rules,availableTags:availableTags,staffOwnerID:staffOwnerID ?? UUID(uuidString:"00000000-0000-0000-0000-000000000000")!,memberCount:0,postCount:0,createdAt:createdAt,archivedAt:archivedAt)}
}
private struct ForumPostDTO:Decodable{
    let id:UUID;let communityID:UUID?;let gymID:UUID?;let authorID:UUID;let kind:String;let title:String;let body:String;let tag:String?;let attachments:[ForumAttachment];let poll:ForumPoll?;let liftID:UUID?;let workoutID:UUID?;let linkURL:String?;let challengeID:UUID?;let isPinned:Bool;let isLocked:Bool;let removedAt:Date?;let removalReason:String?;let createdAt:Date;let editedAt:Date?
    enum CodingKeys:String,CodingKey{case id,kind,title,body,tag,attachments,poll;case communityID="community_id",gymID="gym_id",authorID="author_id",liftID="lift_id",workoutID="workout_id",linkURL="link_url",challengeID="challenge_id",isPinned="is_pinned",isLocked="is_locked",removedAt="removed_at",removalReason="removal_reason",createdAt="created_at",editedAt="edited_at"}
    func post(authorName:String,commentCount:Int,votes:[UUID:CommunityVote],saves:Set<UUID>,watches:Set<UUID>)->ForumPost{.init(id:id,destination:communityID.map(ForumDestination.community) ?? .gym(gymID!),authorID:authorID,authorName:authorName,kind:ForumPostKind(rawValue:kind) ?? .discussion,title:title,body:body,tag:tag,attachments:attachments,poll:poll,liftID:liftID,workoutID:workoutID,linkURL:linkURL.flatMap(URL.init(string:)),challengeID:challengeID,createdAt:createdAt,editedAt:editedAt,commentCount:commentCount,votes:votes,savedByUserIDs:saves,watchedByUserIDs:watches,isPinned:isPinned,isLocked:isLocked,removedAt:removedAt,removalReason:removalReason)}
}
private struct ForumPostInsertDTO:Encodable{
    let id:UUID;let communityID:UUID?;let gymID:UUID?;let authorID:UUID;let kind:String;let title:String;let body:String;let tag:String?;let attachments:[ForumAttachment];let poll:ForumPoll?;let liftID:UUID?;let workoutID:UUID?;let linkURL:String?;let challengeID:UUID?;let createdAt:Date
    enum CodingKeys:String,CodingKey{case id,kind,title,body,tag,attachments,poll;case communityID="community_id",gymID="gym_id",authorID="author_id",liftID="lift_id",workoutID="workout_id",linkURL="link_url",challengeID="challenge_id",createdAt="created_at"}
    init(post:ForumPost,userID:UUID){id=post.id;communityID=post.destination.communityID;gymID=post.destination.gymID;authorID=userID;kind=post.kind.rawValue;title=post.title;body=post.body;tag=post.tag;attachments=post.attachments;poll=post.poll;liftID=post.liftID;workoutID=post.workoutID;linkURL=post.linkURL?.absoluteString;challengeID=post.challengeID;createdAt=post.createdAt}
}
private struct ForumCommentDTO:Decodable{let id:UUID;let postID:UUID;let parentCommentID:UUID?;let authorID:UUID;let body:String;let createdAt:Date;let editedAt:Date?;let removedAt:Date?;let removalReason:String?;enum CodingKeys:String,CodingKey{case id,body;case postID="post_id",parentCommentID="parent_comment_id",authorID="author_id",createdAt="created_at",editedAt="edited_at",removedAt="removed_at",removalReason="removal_reason"};func comment(authorName:String,votes:[UUID:CommunityVote])->ForumComment{.init(id:id,postID:postID,parentCommentID:parentCommentID,authorID:authorID,authorName:authorName,body:body,createdAt:createdAt,editedAt:editedAt,votes:votes,removedAt:removedAt,removalReason:removalReason)}}
private struct ForumCommentInsertDTO:Encodable{let id:UUID;let postID:UUID;let parentCommentID:UUID?;let authorID:UUID;let body:String;enum CodingKeys:String,CodingKey{case id,body;case postID="post_id",parentCommentID="parent_comment_id",authorID="author_id"}}
private struct ForumPostVoteDTO:Decodable{let postID:UUID;let userID:UUID;let value:Int;enum CodingKeys:String,CodingKey{case value;case postID="post_id",userID="user_id"};var vote:CommunityVote{CommunityVote(rawValue:value) ?? .up}}
private struct ForumCommentVoteDTO:Decodable{let commentID:UUID;let userID:UUID;let value:Int;enum CodingKeys:String,CodingKey{case value;case commentID="comment_id",userID="user_id"};var vote:CommunityVote{CommunityVote(rawValue:value) ?? .up}}
private struct ForumPostUserDTO:Codable{let postID:UUID;let userID:UUID;enum CodingKeys:String,CodingKey{case postID="post_id",userID="user_id"}}
private struct ForumPollVoteDTO:Encodable{let postID:UUID;let optionID:UUID;let userID:UUID;enum CodingKeys:String,CodingKey{case postID="post_id",optionID="option_id",userID="user_id"}}
private struct ForumReportInsertDTO:Encodable{let communityID:UUID?;let targetType:String;let targetID:UUID;let reporterID:UUID;let reason:String;let note:String;enum CodingKeys:String,CodingKey{case reason,note;case communityID="community_id",targetType="target_type",targetID="target_id",reporterID="reporter_id"}}
private struct ForumVoteInsertDTO:Encodable{
    let targetColumn:String;let targetID:UUID;let userID:UUID;let value:Int
    struct DynamicKey:CodingKey{var stringValue:String;init?(stringValue:String){self.stringValue=stringValue};var intValue:Int?{nil};init?(intValue:Int){nil}}
    func encode(to encoder:Encoder)throws{var c=encoder.container(keyedBy:DynamicKey.self);try c.encode(targetID,forKey:DynamicKey(stringValue:targetColumn)!);try c.encode(userID,forKey:DynamicKey(stringValue:"user_id")!);try c.encode(value,forKey:DynamicKey(stringValue:"value")!)}
}
